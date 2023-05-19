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
import 'provider.dart';
import 'package:meta/meta.dart';

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

  Future<TransportPayload> read({bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.read(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleSingleRead, onError: _handleSingleError);
  }

  Future<void> writeSingle(Uint8List bytes, {bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleSingleWrite, onError: _handleSingleError);
  }

  Future<void> writeMany(List<Uint8List> bytes, {bool submit = true}) async {
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forClient();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _links.setOutbound(bufferId, lastBufferId);
      _channel.write(
        bytes[index],
        bufferIds[index],
        _writeTimeout,
        transportEventWrite | transportEventClient | transportEventLink,
        listenerSqeFlags: transportIosqeIoLink,
      );
    }
    final completer = Completer<int>();
    _callbacks.setOutbound(lastBufferId, completer);
    _links.setOutbound(lastBufferId, lastBufferId);
    _channel.write(
      bytes.last,
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventClient | transportEventLink,
    );
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyWrite, onError: _handleManyWrite);
  }

  Future<TransportPayload> receiveSingleMessage({bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutbound(bufferId, completer);
    _channel.receiveMessage(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleSingleRead, onError: _handleSingleError);
  }

  Future<List<TransportPayload>> receiveManyMessage(int count, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(count);
    if (_closing) throw TransportClosedException.forClient();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < count - 1; index++) {
      final bufferId = bufferIds[index];
      _links.setOutbound(bufferId, lastBufferId);
      _channel.receiveMessage(
        bufferId,
        _pointer.ref.family,
        _readTimeout,
        flags,
        transportEventReceiveMessage | transportEventClient | transportEventLink,
        listenerSqeFlags: transportIosqeIoLink,
      );
    }
    final completer = Completer<int>();
    _callbacks.setOutbound(lastBufferId, completer);
    _links.setOutbound(lastBufferId, lastBufferId);
    _channel.receiveMessage(
      lastBufferId,
      _pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventClient | transportEventLink,
    );
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyReceive, onError: _handleManyError);
  }

  Future<void> sendSingleMessage(Uint8List bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<int>();
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
    return completer.future.then(_handleSingleWrite, onError: _handleSingleError);
  }

  Future<void> sendManyMessages(List<Uint8List> bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _links.setOutbound(bufferId, lastBufferId);
      _channel.sendMessage(
        bytes[index],
        bufferId,
        _pointer.ref.family,
        _destination,
        _writeTimeout,
        flags,
        transportEventSendMessage | transportEventClient | transportEventLink,
        listenerSqeFlags: transportIosqeIoLink,
      );
    }
    final completer = Completer<int>();
    _links.setOutbound(lastBufferId, lastBufferId);
    _callbacks.setOutbound(lastBufferId, completer);
    _channel.sendMessage(
      bytes.last,
      lastBufferId,
      _pointer.ref.family,
      _destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient | transportEventLink,
    );
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyWrite, onError: _handleManyError);
  }

  @pragma(preferInlinePragma)
  Future<TransportClient> connect() {
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<TransportClient>();
    _callbacks.setConnect(_pointer.ref.fd, completer);
    _bindings.transport_worker_connect(_workerPointer, _pointer, _connectTimeout!);
    _pending++;
    return completer.future;
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
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _pointer.ref.fd);
    if (_pending > 0) await _closer.future;
    _channel.close();
    _registry.remove(_pointer.ref.fd);
    _bindings.transport_client_destroy(_pointer);
  }

  @pragma(preferInlinePragma)
  TransportPayload _handleSingleRead(int bufferId) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId));

  @pragma(preferInlinePragma)
  List<TransportPayload> _handleManyReceive(int lastBufferId) => _links.selectOutbound(lastBufferId).map((bufferId) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId))).toList();

  @pragma(preferInlinePragma)
  void _handleSingleWrite(int bufferId) => _buffers.release(bufferId);

  @pragma(preferInlinePragma)
  void _handleManyWrite(int lastBufferId) => _buffers.releaseArray(_links.selectOutbound(lastBufferId).toList());

  @pragma(preferInlinePragma)
  void _handleSingleError(error) {
    if (error is TransportExecutionException && error.bufferId != null) {
      _buffers.release(error.bufferId!);
    }
    throw error;
  }

  @pragma(preferInlinePragma)
  void _handleManyError(error) {
    if (error is TransportExecutionException && error.bufferId != null) {
      _buffers.releaseArray(_links.selectOutbound(error.bufferId!).toList());
    }
    throw error;
  }

  @visibleForTesting
  TransportClientRegistry get registry => _registry;
}

class TransportClientStreamPool {
  final List<TransportClientStreamProvider> _clients;
  var _next = 0;

  List<TransportClientStreamProvider> get clients => _clients;

  TransportClientStreamPool(this._clients);

  @pragma(preferInlinePragma)
  TransportClientStreamProvider select() {
    final provider = _clients[_next];
    if (++_next == _clients.length) _next = 0;
    return provider;
  }

  @pragma(preferInlinePragma)
  void forEach(FutureOr<void> Function(TransportClientStreamProvider provider) action) => _clients.forEach(action);

  @pragma(preferInlinePragma)
  Iterable<Future<M>> map<M>(Future<M> Function(TransportClientStreamProvider provider) mapper) => _clients.map(mapper);

  @pragma(preferInlinePragma)
  int count() => _clients.length;

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => Future.wait(_clients.map((provider) => provider.close(gracefulDuration: gracefulDuration)));
}
