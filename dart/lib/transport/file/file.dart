import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../links.dart';
import '../payload.dart';
import 'registry.dart';
import 'package:meta/meta.dart';

class TransportFile {
  final String path;
  final int _fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportChannel _channel;
  final TransportCallbacks _callbacks;
  final TransportBuffers buffers;
  final TransportLinks _links;
  final TransportPayloadPool _payloadPool;
  final TransportFileRegistry _registry;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportFile(
    this.path,
    this._fd,
    this._bindings,
    this._workerPointer,
    this._callbacks,
    this._channel,
    this.buffers,
    this._links,
    this._payloadPool,
    this._registry,
  );

  Future<TransportPayload> readSingle({bool submit = true, int offset = 0}) async {
    Completer<int>? completer = Completer<int>();
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forFile();
    _callbacks.setOutbound(bufferId, completer);
    _channel.read(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleSingleRead, onError: _handleSingleError).whenComplete(() => completer = null);
  }

  Future<void> writeSingle(Uint8List bytes, {bool submit = true, int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = buffers.get() ?? await buffers.allocate();
    if (_closing) throw TransportClosedException.forFile();
    _callbacks.setOutbound(bufferId, completer);
    _channel.write(bytes, bufferId, transportTimeoutInfinity, transportEventWrite | transportEventFile, offset: offset);
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future.then(_handleSingleWrite, onError: _handleSingleError);
  }

  Future<Uint8List> readMany(int count, {bool submit = true, int offset = 0}) async {
    final bufferIds = await buffers.allocateArray(count);
    if (_closing) throw TransportClosedException.forFile();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < count - 1; index++) {
      final bufferId = bufferIds[index];
      _links.setOutbound(bufferId, lastBufferId);
      _channel.read(
        bufferId,
        transportTimeoutInfinity,
        transportEventRead | transportEventFile | transportEventLink,
        sqeFlags: transportIosqeIoLink,
        offset: offset,
      );
      offset += buffers.bufferSize;
    }
    final completer = Completer<int>();
    _links.setOutbound(lastBufferId, lastBufferId);
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.read(
      lastBufferId,
      transportTimeoutInfinity,
      transportEventRead | transportEventFile | transportEventLink,
      offset: offset,
    );
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyRead, onError: _handleManyError);
  }

  Future<void> writeMany(List<Uint8List> bytes, {bool submit = true, int offset = 0}) async {
    final bufferIds = await buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forFile();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _links.setOutbound(bufferId, lastBufferId);
      _channel.write(
        bytes[index],
        bufferId,
        transportTimeoutInfinity,
        transportEventWrite | transportEventFile | transportEventLink,
        sqeFlags: transportIosqeIoLink,
        offset: offset,
      );
      offset += buffers.bufferSize;
    }
    final completer = Completer<int>();
    _links.setOutbound(lastBufferId, lastBufferId);
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.write(
      bytes.last,
      lastBufferId,
      transportTimeoutInfinity,
      transportEventWrite | transportEventFile | transportEventLink,
      offset: offset,
    );
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future.then(_handleManyWrite, onError: _handleManyError);
  }

  @pragma(preferInlinePragma)
  bool notify() {
    _pending--;
    if (_active) return true;
    if (_pending == 0) _closer.complete();
    return false;
  }

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _fd);
    if (_pending > 0) await _closer.future;
    _channel.close();
    _registry.remove(_fd);
  }

  @pragma(preferInlinePragma)
  TransportPayload _handleSingleRead(int bufferId) => _payloadPool.getPayload(bufferId, buffers.read(bufferId));

  @pragma(preferInlinePragma)
  Uint8List _handleManyRead(int lastBufferId) {
    final bytes = BytesBuilder();
    for (var bufferId in _links.selectOutbound(lastBufferId)) {
      final payload = buffers.read(bufferId);
      if (payload.isEmpty) break;
      bytes.add(payload);
      buffers.release(bufferId);
    }
    return bytes.takeBytes();
  }

  @pragma(preferInlinePragma)
  void _handleSingleWrite(int bufferId) => buffers.release(bufferId);

  @pragma(preferInlinePragma)
  void _handleManyWrite(int lastBufferId) => buffers.releaseArray(_links.selectOutbound(lastBufferId).toList());

  @pragma(preferInlinePragma)
  void _handleSingleError(error) {
    if (error is TransportExecutionException && error.bufferId != null) {
      buffers.release(error.bufferId!);
    }
    throw error;
  }

  @pragma(preferInlinePragma)
  void _handleManyError(error) {
    if (error is TransportExecutionException && error.bufferId != null) {
      buffers.releaseArray(_links.selectOutbound(error.bufferId!).toList());
    }
    throw error;
  }

  @visibleForTesting
  TransportFileRegistry get registry => _registry;
}
