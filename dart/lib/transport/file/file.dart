import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'registry.dart';
import 'package:meta/meta.dart';

class TransportFileChannel {
  final StreamController<TransportPayload> _inboundEvents = StreamController();
  final StreamController<void> _outboundEvents = StreamController();

  final String path;
  final int _fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportChannel _channel;
  final TransportBuffers buffers;
  final TransportPayloadPool _payloadPool;
  final TransportFileRegistry _registry;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportFileChannel(
    this.path,
    this._fd,
    this._bindings,
    this._workerPointer,
    this._channel,
    this.buffers,
    this._payloadPool,
    this._registry,
  );

  Stream<TransportPayload> get inbound => _inboundEvents.stream;
  Stream<void> get outbound => _outboundEvents.stream;

  Future<void> readSingle({int offset = 0}) async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forFile();
    _channel.read(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    _pending++;
  }

  Future<void> writeSingle(Uint8List bytes, {int offset = 0}) async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forFile();
    _channel.write(bytes, bufferId, transportTimeoutInfinity, transportEventWrite | transportEventFile, offset: offset);
    _pending++;
  }

  Future<void> readMany(int count, {int offset = 0}) async {
    final bufferIds = await buffers.allocateArray(count);
    if (_closing) throw TransportClosedException.forFile();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < count - 1; index++) {
      final bufferId = bufferIds[index];
      _channel.read(
        bufferId,
        transportTimeoutInfinity,
        transportEventRead | transportEventFile,
        sqeFlags: transportIosqeIoLink,
        offset: offset,
      );
      offset += buffers.bufferSize;
    }
    _channel.read(
      lastBufferId,
      transportTimeoutInfinity,
      transportEventRead | transportEventFile,
      offset: offset,
    );
    _pending += count;
  }

  Future<void> writeMany(List<Uint8List> bytes, {int offset = 0}) async {
    final bufferIds = await buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forFile();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _channel.write(
        bytes[index],
        bufferId,
        transportTimeoutInfinity,
        transportEventWrite | transportEventFile,
        sqeFlags: transportIosqeIoLink,
        offset: offset,
      );
      offset += buffers.bufferSize;
    }
    _channel.write(
      bytes.last,
      lastBufferId,
      transportTimeoutInfinity,
      transportEventWrite | transportEventFile,
      offset: offset,
    );
    _pending += bytes.length;
  }

  void notify(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (event == transportEventRead || event == transportEventReceiveMessage) {
        if (result >= 0) {
          buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getPayload(bufferId, buffers.read(bufferId)));
          return;
        }
        buffers.release(bufferId);
        _inboundEvents.addError(createTransportException(TransportEvent.ofEvent(event), result, _bindings));
        return;
      }
      if (result >= 0) {
        buffers.release(bufferId);
        return;
      }
      _outboundEvents.addError(createTransportException(
        TransportEvent.ofEvent(event),
        result,
        _bindings,
        payload: _payloadPool.getPayload(bufferId, buffers.read(bufferId)),
      ));
      return;
    }
    buffers.release(bufferId);
    if (event == transportEventRead || event == transportEventReceiveMessage) {
      _inboundEvents.addError(TransportClosedException.forFile());
      if (_pending == 0) _closer.complete();
      return;
    }
    _outboundEvents.addError(TransportClosedException.forFile());
    if (_pending == 0) _closer.complete();
  }

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    await _inboundEvents.close();
    await _outboundEvents.close();
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _fd);
    if (_pending > 0) await _closer.future;
    _channel.close();
    _registry.remove(_fd);
  }

  @visibleForTesting
  TransportFileRegistry get registry => _registry;
}
