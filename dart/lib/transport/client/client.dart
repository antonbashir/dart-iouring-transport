import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import '../chunk.dart';
import 'registry.dart';

import 'communicator.dart';

class TransportClient {
  final TransportCallbacks _callbacks;
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

  late final String source;
  late final String destination;
  late final Pointer<sockaddr> _destination;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;
  final _closer = Completer();

  var _pending = 0;

  TransportClient(
    this._callbacks,
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

  Future<List<TransportPayload>> readBatch(int count) async {
    final chunks = <Future<TransportPayload>>[];
    final allocatedBuffers = <int>[];
    for (var index = 0; index < count; index++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
    if (_closing) throw TransportClosedException.forClient();
    for (var index = 0; index < count - 1; index++) {
      final completer = Completer<int>();
      final bufferId = allocatedBuffers[index];
      _callbacks.setOutboundBuffer(bufferId, completer);
      _channel.addRead(bufferId, _readTimeout, transportEventRead | transportEventClient);
      chunks.add(completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length))));
    }
    final completer = Completer<int>();
    final bufferId = allocatedBuffers[count - 1];
    _callbacks.setOutboundBuffer(bufferId, completer);
    _channel.readSubmit(bufferId, _readTimeout, transportEventRead | transportEventClient);
    chunks.add(completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length))));
    _pending += chunks.length;
    return Future.wait(chunks);
  }

  Future<TransportPayload> read() async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutboundBuffer(bufferId, completer);
    _channel.readSubmit(bufferId, _readTimeout, transportEventRead | transportEventClient);
    _pending++;
    return completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length)));
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => bytes.length > _buffers.bufferSize ? _writeChunked(bytes) : _writeSubmit(bytes);

  Future<void> writeBatch(Iterable<Uint8List> fragments) async {
    final chunks = <TransportChunk>[];
    for (var fragment in fragments) chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), fragment));
    if (_closing) throw TransportClosedException.forClient();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(chunk.bufferId, completer);
      _channel.addWrite(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(chunk.bufferId, completer);
    _channel.writeSubmit(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending += chunks.length;
    return completer.future;
  }

  Future<void> _writeSubmit(Uint8List bytes) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.writeSubmit(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<void> _writeChunked(Uint8List bytes) async {
    final chunks = <TransportChunk>[];
    var offset = 0;
    while (bytes.isNotEmpty) {
      final limit = min(bytes.length, _buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), bytes));
      offset += limit;
    }
    if (_closing) throw TransportClosedException.forClient();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(chunk.bufferId, completer);
      _channel.addWrite(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(chunk.bufferId, completer);
    _channel.writeSubmit(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventClient);
    _pending += chunks.length;
    return completer.future;
  }

  Future<List<TransportPayload>> receiveMessageBatch(int count, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <Future<TransportPayload>>[];
    final allocatedBuffers = <int>[];
    for (var index = 0; index < count; index++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
    if (_closing) throw TransportClosedException.forClient();
    for (var index = 0; index < count - 1; index++) {
      final completer = Completer<int>();
      final bufferId = allocatedBuffers[index];
      _callbacks.setOutboundBuffer(bufferId, completer);
      _channel.addReceiveMessage(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
      chunks.add(completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length))));
    }
    final completer = Completer<int>();
    final bufferId = allocatedBuffers[count - 1];
    _callbacks.setOutboundBuffer(bufferId, completer);
    _channel.receiveMessageSubmit(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    chunks.add(completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length))));
    _pending += chunks.length;
    return Future.wait(chunks);
  }

  Future<TransportPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<int>();
    _callbacks.setOutboundBuffer(bufferId, completer);
    _channel.receiveMessageSubmit(bufferId, _pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventClient);
    _pending++;
    return completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length)));
  }

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => bytes.length > _buffers.bufferSize ? _sendMessageChunks(bytes, flags: flags) : _sendMessageSubmit(bytes, flags: flags);

  Future<void> _sendMessageChunks(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <TransportChunk>[];
    var offset = 0;
    while (bytes.isNotEmpty) {
      final limit = min(bytes.length, _buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), bytes));
      offset += limit;
    }
    if (_closing) throw TransportClosedException.forClient();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(chunk.bufferId, completer);
      _channel.addSendMessage(chunk.bytes, chunk.bufferId, _pointer.ref.family, _destination, _writeTimeout, flags, transportEventSendMessage | transportEventClient);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(chunk.bufferId, completer);
    _channel.sendMessageSubmit(chunk.bytes, chunk.bufferId, _pointer.ref.family, _destination, _writeTimeout, flags, transportEventSendMessage | transportEventClient);
    _pending += chunks.length;
    return completer.future;
  }

  Future<void> _sendMessageSubmit(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forClient();
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(bufferId, completer);
    _channel.sendMessageSubmit(bytes, bufferId, _pointer.ref.family, _destination, _writeTimeout, flags, transportEventSendMessage | transportEventClient);
    _pending++;
    return completer.future;
  }

  Future<void> sendMessageBatch(Iterable<Uint8List> fragments, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <TransportChunk>[];
    for (var fragment in fragments) chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), fragment));
    if (_closing) throw TransportClosedException.forClient();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setOutboundWrite(chunk.bufferId, completer);
      _channel.addSendMessage(chunk.bytes, chunk.bufferId, _pointer.ref.family, _destination, _writeTimeout, flags, transportEventSendMessage | transportEventClient);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setOutboundWrite(chunk.bufferId, completer);
    _channel.sendMessageSubmit(chunk.bytes, chunk.bufferId, _pointer.ref.family, _destination, _writeTimeout, flags, transportEventSendMessage | transportEventClient);
    _pending += chunks.length;
    return completer.future;
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

  @pragma(preferInlinePragma)
  bool hasPending() => _pending > 0;

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
