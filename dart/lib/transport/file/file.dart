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
  final _inboundEvents = StreamController<TransportPayload>();
  final _outboundErrorHandlers = <int, void Function(Exception error)>{};
  final _outboundDoneHandlers = <int, void Function()>{};

  final String path;
  final int _fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportChannel _channel;
  final TransportBuffers buffers;
  final TransportPayloadPool _payloadPool;
  final TransportFileRegistry _registry;

  var _pending = 0;
  var _active = true;
  var _closing = false;
  final _closer = Completer();

  bool get active => !_closing;
  Stream<TransportPayload> get inbound => _inboundEvents.stream;

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

  Future<void> readSingle({int offset = 0}) async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) return Future.error(TransportClosedException.forFile());
    _channel.read(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    _pending++;
  }

  Future<void> writeSingle(
    Uint8List bytes, {
    int offset = 0,
    void Function(Exception error)? onError,
    void Function()? onDone,
  }) async {
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) return Future.error(TransportClosedException.forFile());
    if (onError != null) _outboundErrorHandlers[bufferId] = onError;
    if (onDone != null) _outboundDoneHandlers[bufferId] = onDone;
    _channel.write(bytes, bufferId, transportTimeoutInfinity, transportEventWrite | transportEventFile, offset: offset);
    _pending++;
  }

  Future<void> readMany(int count, {int offset = 0}) async {
    final bufferIds = await buffers.allocateArray(count);
    if (_closing) return Future.error(TransportClosedException.forFile());
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

  Future<void> writeMany(
    List<Uint8List> bytes, {
    int offset = 0,
    void Function(Exception error)? onError,
    void Function()? onDone,
  }) async {
    final bufferIds = await buffers.allocateArray(bytes.length);
    if (_closing) return Future.error(TransportClosedException.forFile());
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
      if (onError != null) _outboundErrorHandlers[bufferId] = onError;
      if (onDone != null) _outboundDoneHandlers[bufferId] = onDone;
    }
    _channel.write(
      bytes.last,
      lastBufferId,
      transportTimeoutInfinity,
      transportEventWrite | transportEventFile,
      offset: offset,
    );
    if (onError != null) _outboundErrorHandlers[lastBufferId] = onError;
    if (onDone != null) _outboundDoneHandlers[lastBufferId] = onDone;
    _pending += bytes.length;
  }

  void notify(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (event == transportEventRead) {
        if (result >= 0) {
          buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getPayload(bufferId, buffers.read(bufferId)));
          return;
        }
        buffers.release(bufferId);
        _inboundEvents.addError(createTransportException(TransportEvent.fileEvent(event), result, _bindings));
        return;
      }
      buffers.release(bufferId);
      if (result >= 0) {
        _outboundDoneHandlers.remove(bufferId)?.call();
        return;
      }
      _outboundErrorHandlers.remove(bufferId)?.call(createTransportException(TransportEvent.fileEvent(event), result, _bindings));
      return;
    }
    buffers.release(bufferId);
    if (_pending == 0) _closer.complete();
  }

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) {
      if (!_closer.isCompleted) {
        if (_pending > 0) await _closer.future;
      }
      return;
    }
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _fd);
    if (_pending > 0) await _closer.future;
    if (_inboundEvents.hasListener) await _inboundEvents.close();
    _channel.close();
    _registry.remove(_fd);
  }

  @visibleForTesting
  TransportFileRegistry get registry => _registry;
}
