import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import '../exception.dart';
import 'registry.dart';

import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../links.dart';
import '../payload.dart';

class TransportFile {
  final String path;
  final int _fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportChannel _channel;
  final TransportCallbacks _callbacks;
  final TransportBuffers _buffers;
  final TransportLinks _links;
  final TransportPayloadPool _payloadPool;
  final TransportFileRegistry _registry;
  final File delegate;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportFile(
    this.path,
    this.delegate,
    this._fd,
    this._bindings,
    this._workerPointer,
    this._callbacks,
    this._channel,
    this._buffers,
    this._links,
    this._payloadPool,
    this._registry,
  );

  Future<TransportPayload> readSingle({bool submit = true, int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forFile();
    _callbacks.setOutbound(bufferId, completer);
    _channel.read(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId)), onError: (error) {
      _buffers.release(bufferId);
      throw error;
    });
  }

  Future<void> writeSingle(Uint8List bytes, {bool submit = true, int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forFile();
    _callbacks.setOutbound(bufferId, completer);
    _channel.write(bytes, bufferId, transportTimeoutInfinity, transportEventWrite | transportEventFile, offset: offset);
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future.whenComplete(() => _buffers.release(bufferId));
  }

  Future<Uint8List> readMany(int count, {bool submit = true, int offset = 0}) async {
    final bytes = BytesBuilder();
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < count - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      offset += _buffers.bufferSize;
      _links.setOutbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forFile();
    for (var index = 0; index < count - 1; index++) {
      _channel.read(
        bufferIds[index],
        transportTimeoutInfinity,
        transportEventRead | transportEventFile | transportEventLink,
        sqeFlags: transportIosqeIoLink,
        offset: offset,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.read(
      lastBufferId,
      transportTimeoutInfinity,
      transportEventRead | transportEventFile | transportEventLink,
      offset: offset,
    );
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future.onError<Exception>((error, _) {
      for (var bufferId in bufferIds) _buffers.release(bufferId);
      throw error;
    });
    for (var bufferId in bufferIds) {
      final payload = _buffers.read(bufferId);
      if (payload.isEmpty) break;
      bytes.add(payload);
    }
    for (var bufferId in bufferIds) _buffers.release(bufferId);
    return bytes.takeBytes();
  }

  Future<Uint8List> load({int blocksCount = 1, int offset = 0}) {
    if (blocksCount == 1) return readSingle(submit: true).then((value) => value.takeBytes());
    final bytes = BytesBuilder();
    return readMany(blocksCount, offset: offset).then((value) {
      if (value.isEmpty) return value;
      bytes.add(value);
      return load(blocksCount: blocksCount, offset: offset + value.length);
    });
  }

  Future<void> writeMany(List<Uint8List> bytes, {bool submit = true, int offset = 0}) async {
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      offset += _buffers.bufferSize;
      _links.setOutbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forFile();
    for (var index = 0; index < bytes.length - 1; index++) {
      _channel.write(
        bytes[index],
        bufferIds[index],
        transportTimeoutInfinity,
        transportEventWrite | transportEventFile | transportEventLink,
        sqeFlags: transportIosqeIoLink,
        offset: offset,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.write(
      bytes[bytes.length - 1],
      lastBufferId,
      transportTimeoutInfinity,
      transportEventWrite | transportEventFile | transportEventLink,
      offset: offset,
    );
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future.whenComplete(() {
      for (var bufferId in bufferIds) _buffers.release(bufferId);
    });
  }

  bool notify(int bufferId) {
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
}
