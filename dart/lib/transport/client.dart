import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'registry.dart';

import 'bindings.dart';
import 'buffers.dart';
import 'channels.dart';
import 'communicator.dart';
import 'constants.dart';
import 'exception.dart';
import 'payload.dart';
import 'callbacks.dart';

class TransportClient {
  final TransportCallbacks _callbacks;
  final Pointer<transport_client_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportChannel _channel;
  final TransportBindings _bindings;
  final int? connectTimeout;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportBuffers _buffers;
  final TransportClientRegistry _registry;

  var _active = true;
  bool get active => _active;
  final _closer = Completer();

  var _pending = 0;

  TransportClient(
    this._callbacks,
    this._channel,
    this.pointer,
    this._workerPointer,
    this._bindings,
    this._readTimeout,
    this._writeTimeout,
    this._buffers,
    this._registry, {
    this.connectTimeout,
  });

  Future<TransportOutboundPayload> read() async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.read(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId)));
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<TransportOutboundPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    return completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId)));
  }

  Future<void> sendMessage(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!_active) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.sendMessage(
      bytes,
      bufferId,
      pointer.ref.family,
      _bindings.transport_client_get_destination_address(pointer),
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventClient,
    );
    _pending++;
    return completer.future;
  }

  Future<TransportClient> connect(Pointer<transport_worker_t> workerPointer) {
    final completer = Completer<TransportClient>();
    _callbacks.setConnect(pointer.ref.fd, completer);
    _bindings.transport_worker_connect(workerPointer, pointer, connectTimeout!);
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

  @pragma(preferInlinePragma)
  bool hasPending() => _pending > 0;

  Future<void> close() async {
    if (!_active) return;
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, pointer.ref.fd);
    if (_pending > 0) await _closer.future;
    _channel.close();
    _bindings.transport_client_destroy(pointer);
    _registry.removeClient(pointer.ref.fd);
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
