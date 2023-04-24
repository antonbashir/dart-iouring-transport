import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../links.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'registry.dart';

import 'communicator.dart';

class TransportClient {
  final TransportCallbacks _callbacks;
  final TransportLinks _links;
  final Pointer<transport_client_t> _pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportChannel _channel;
  final TransportBindings _bindings;
  final int? _connectTimeout;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportBuffers _buffers;
  final TransportClientRegistry _registry;
  final TransportPayloadPool _payloadPool;

  late final Pointer<sockaddr> _destination;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportClient(
    this._callbacks,
    this._links,
    this._channel,
    this._pointer,
    this._workerPointer,
    this._bindings,
    this._readTimeout,
    this._writeTimeout,
    this._buffers,
    this._registry,
    this._payloadPool, {
    int? connectTimeout,
  }) : _connectTimeout = connectTimeout {
    _destination = _bindings.transport_client_get_destination_address(_pointer);
  }

  Future<TransportPayload> readSingle({bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.read(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then((_) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
  }

  Future<List<TransportPayload>> readMany(int count, {bool submit = true}) async {
    final messages = <TransportPayload>[];
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < count - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setOutbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forClient();
    for (var index = 0; index < count - 1; index++) {
      _channel.read(
        bufferIds[index],
        _readTimeout,
        transportEventRead | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.read(
      lastBufferId,
      _readTimeout,
      transportEventRead | transportEventClient | transportEventLink,
    );
    _pending += count;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future;
    for (var bufferId in bufferIds) messages.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
    return messages;
  }

  Future<void> writeSingle(Uint8List bytes, {bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future;
  }

  Future<void> writeMany(List<Uint8List> bytes, {bool submit = true}) async {
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setOutbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forClient();
    for (var index = 0; index < bytes.length - 1; index++) {
      _channel.write(
        bytes[index],
        bufferIds[index],
        _writeTimeout,
        transportEventWrite | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.write(
      bytes[bytes.length - 1],
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventClient | transportEventLink,
    );
    _pending += bytes.length;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future;
  }

  Future<TransportPayload> receiveSingleMessage({bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.receiveMessage(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then((_) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
  }

  Future<List<TransportPayload>> receiveManyMessage(int count, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final messages = <TransportPayload>[];
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < count - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setInbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forClient();
    for (var index = 0; index < count - 1; index++) {
      _channel.receiveMessage(
        bufferIds[index],
        _pointer.ref.family,
        _readTimeout,
        flags,
        transportEventReceiveMessage | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setInbound(lastBufferId, completer);
    _channel.receiveMessage(
      lastBufferId,
      _pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventClient | transportEventLink,
    );
    _pending += count;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future;
    for (var bufferId in bufferIds) messages.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
    return messages;
  }

  Future<void> sendSingleMessage(Uint8List bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.sendMessage(
      bytes,
      bufferId,
      _pointer.ref.family,
      _destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient,
    );
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future;
  }

  Future<void> sendManyMessages(List<Uint8List> bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setInbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forServer();
    for (var index = 0; index < bytes.length - 1; index++) {
      _channel.sendMessage(
        bytes[index],
        bufferIds[index],
        _pointer.ref.family,
        _destination,
        _writeTimeout,
        flags,
        transportEventSendMessage | transportEventClient | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setInbound(lastBufferId, completer);
    _channel.sendMessage(
      bytes[bytes.length - 1],
      lastBufferId,
      _pointer.ref.family,
      _destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient | transportEventLink,
    );
    _pending += bytes.length;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future;
  }

  Future<TransportClient> connect() {
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<TransportClient>();
    _callbacks.setConnect(_pointer.ref.fd, completer);
    _bindings.transport_worker_connect(_workerPointer, _pointer, _connectTimeout!);
    _pending++;
    return completer.future;
  }

  @pragma(preferInlinePragma)
  bool notifyConnect() {
    _pending--;
    if (_active) return true;
    if (_pending == 0) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool notifyData(int bufferId) {
    _pending--;
    if (_active) return true;
    _buffers.release(bufferId);
    if (_pending == 0) _closer.complete();
    return false;
  }

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _pointer.ref.fd);
    if (_pending > 0) await _closer.future;
    _channel.close();
    _bindings.transport_client_destroy(_pointer);
    _registry.removeClient(_pointer.ref.fd);
  }
}

class TransportClientStreamCommunicators {
  final List<TransportClientStreamCommunicator> _communicators;
  var _next = 0;

  TransportClientStreamCommunicators(this._communicators);

  TransportClientStreamCommunicator select() {
    final client = _communicators[_next];
    if (++_next == _communicators.length) _next = 0;
    return client;
  }

  void forEach(FutureOr<void> Function(TransportClientStreamCommunicator communicator) action) => _communicators.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(TransportClientStreamCommunicator communicator) mapper) => _communicators.map(mapper);
}
