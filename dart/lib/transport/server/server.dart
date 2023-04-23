import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import '../chunk.dart';
import 'connection.dart';
import 'registry.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';

class _TransportConnectionState {
  var active = true;
  var closing = false;
  var pending = 0;
  Completer<void> closer = Completer();
}

class TransportServer {
  final _closer = Completer();
  final _connections = <int, _TransportConnectionState>{};

  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportCallbacks _callbacks;
  final TransportBuffers _buffers;
  final TransportServerRegistry _registry;
  final TransportPayloadPool _payloadPool;

  var _pending = 0;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;

  TransportServer(
    this.pointer,
    this._workerPointer,
    this._bindings,
    this._callbacks,
    this._readTimeout,
    this._writeTimeout,
    this._buffers,
    this._registry,
    this._payloadPool,
  );

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection connection) onAccept) {
    if (_closing) throw TransportClosedException.forServer();
    _callbacks.setAccept(pointer.ref.fd, (channel) {
      _connections[channel.fd] = _TransportConnectionState();
      onAccept(TransportServerConnection(this, channel));
    });
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  @pragma(preferInlinePragma)
  void reaccept() {
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  Future<TransportPayload> read(int bufferId, TransportChannel channel) async {
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final completer = Completer<int>();
    _callbacks.setInboundRead(bufferId, completer);
    channel.addRead(bufferId, _readTimeout, transportEventRead | transportEventServer, 0);
    connection.pending++;
    return completer.future.then((length) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId, length)));
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes, TransportChannel channel) => bytes.length > _buffers.bufferSize ? _writeChunked(bytes, channel) : _writeSubmit(bytes, channel);

  Future<void> writeBatch(Iterable<Uint8List> fragments, TransportChannel channel) async {
    final chunks = <TransportChunk>[];
    for (var fragment in fragments) chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), fragment));
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setInboundWrite(chunk.bufferId, completer);
      channel.addWrite(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setInboundWrite(chunk.bufferId, completer);
    channel.writeSubmit(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    connection.pending += chunks.length;
    return completer.future;
  }

  Future<void> _writeSubmit(Uint8List bytes, TransportChannel channel) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _callbacks.setInboundWrite(bufferId, completer);
    channel.writeSubmit(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    connection.pending++;
    return completer.future;
  }

  Future<void> _writeChunked(Uint8List bytes, TransportChannel channel) async {
    final chunks = <TransportChunk>[];
    var offset = 0;
    while (bytes.isNotEmpty) {
      final limit = min(bytes.length, _buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), bytes));
      offset += limit;
    }
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setInboundWrite(chunk.bufferId, completer);
      channel.addWrite(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setInboundWrite(chunk.bufferId, completer);
    channel.writeSubmit(chunk.bytes, chunk.bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    connection.pending += chunks.length;
    return completer.future;
  }

  Future<TransportDatagramResponder> receiveMessage(TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final completer = Completer<int>();
    _callbacks.setInboundRead(bufferId, completer);
    channel.receiveMessageSubmit(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventServer);
    _pending++;
    return completer.future.then((length) => _payloadPool.getDatagramResponder(bufferId, _buffers.read(bufferId, length), this, channel));
  }

  Future<List<TransportDatagramResponder>> receiveMessageBatch(TransportChannel channel, int count, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <Future<TransportDatagramResponder>>[];
    final allocatedBuffers = <int>[];
    for (var index = 0; index < count; index++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
    if (_closing) throw TransportClosedException.forServer();
    for (var index = 0; index < count - 1; index++) {
      final completer = Completer<int>();
      final bufferId = allocatedBuffers[index];
      _callbacks.setInboundRead(bufferId, completer);
      channel.addReceiveMessage(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventServer);
      chunks.add(completer.future.then((length) => _payloadPool.getDatagramResponder(bufferId, _buffers.read(bufferId, length), this, channel)));
    }
    final completer = Completer<int>();
    final bufferId = allocatedBuffers[count - 1];
    _callbacks.setInboundRead(bufferId, completer);
    channel.receiveMessageSubmit(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventServer);
    chunks.add(completer.future.then((length) => _payloadPool.getDatagramResponder(bufferId, _buffers.read(bufferId, length), this, channel)));
    _pending += chunks.length;
    return Future.wait(chunks);
  }

  @pragma(preferInlinePragma)
  Future<void> respondMessage(TransportChannel channel, int bufferId, Uint8List bytes, {int? flags}) => bytes.length > _buffers.bufferSize
      ? _respondMessageChunks(
          channel,
          _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId),
          bytes,
          flags: flags,
        )
      : _respondMessageSubmit(
          channel,
          _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId),
          bytes,
          flags: flags,
        );

  Future<void> respondMessageBatch(Iterable<Uint8List> fragments, TransportChannel channel, int bufferId, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final chunks = <TransportChunk>[];
    for (var fragment in fragments) chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), fragment));
    if (_closing) throw TransportClosedException.forServer();
    final destination = _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId);
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setInboundWrite(chunk.bufferId, completer);
      channel.addSendMessage(chunk.bytes, chunk.bufferId, pointer.ref.family, destination, _writeTimeout, flags, transportEventSendMessage | transportEventServer);
    }
    final chunk = chunks[last];
    final completer = Completer<void>();
    _callbacks.setInboundWrite(chunk.bufferId, completer);
    channel.sendMessageSubmit(chunk.bytes, chunk.bufferId, pointer.ref.family, destination, _writeTimeout, flags, transportEventSendMessage | transportEventServer);
    _pending += chunks.length;
    return completer.future;
  }

  Future<void> _respondMessageChunks(TransportChannel channel, Pointer<sockaddr> destination, Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final completer = Completer<void>();
    final chunks = <TransportChunk>[];
    var offset = 0;
    while (bytes.isNotEmpty) {
      final limit = min(bytes.length, _buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      chunks.add(TransportChunk(_buffers.get() ?? await _buffers.allocate(), bytes));
      offset += limit;
    }
    if (_closing) throw TransportClosedException.forServer();
    final last = chunks.length - 1;
    for (var index = 0; index < last; index++) {
      final chunk = chunks[index];
      final completer = Completer<void>();
      _callbacks.setInboundWrite(chunk.bufferId, completer);
      channel.addSendMessage(chunk.bytes, chunk.bufferId, pointer.ref.family, destination, _writeTimeout, flags, transportEventSendMessage | transportEventServer);
    }
    final chunk = chunks[last];
    _callbacks.setInboundWrite(chunk.bufferId, completer);
    channel.sendMessageSubmit(chunk.bytes, chunk.bufferId, pointer.ref.family, destination, _writeTimeout, flags, transportEventSendMessage | transportEventServer);
    _pending += chunks.length;
    return completer.future;
  }

  Future<void> _respondMessageSubmit(TransportChannel channel, Pointer<sockaddr> destination, Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _callbacks.setInboundWrite(bufferId, completer);
    channel.sendMessageSubmit(bytes, bufferId, pointer.ref.family, destination, _writeTimeout, flags, transportEventSendMessage | transportEventServer);
    _pending++;
    return completer.future;
  }

  @pragma(preferInlinePragma)
  bool notifyAccept() {
    _pending--;
    if (_active) return true;
    if (_pending == 0 && _connections.isEmpty) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool notifyData(int bufferId) {
    _pending--;
    if (_active) return true;
    _buffers.release(bufferId);
    if (_pending == 0 && _connections.isEmpty) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool notifyConnectionData(int fd, int bufferId) {
    final connection = _connections[fd]!;
    connection.pending--;
    if (_active && connection.active) return true;
    _buffers.release(bufferId);
    if (!connection.active && connection.pending == 0) connection.closer.complete();
    if (!_active && _pending == 0 && _connections.isEmpty) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool connectionIsActive(int fd) => _connections[fd]?.closing == false;

  @pragma(preferInlinePragma)
  void releaseBuffer(int id) => _buffers.release(id);

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, pointer.ref.fd);
    await Future.wait(_connections.keys.map(closeConnection));
    if (_pending > 0 || _connections.isNotEmpty) await _closer.future;
    _bindings.transport_close_descritor(pointer.ref.fd);
    _bindings.transport_server_destroy(pointer);
    _registry.removeServer(pointer.ref.fd);
  }

  Future<void> closeConnection(int fd, {Duration? gracefulDuration}) async {
    final connection = _connections[fd];
    if (connection == null || connection.closing) return;
    connection.closing = false;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    connection.active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, fd);
    if (connection.pending > 0) await connection.closer.future;
    _registry.removeConnection(fd);
    _connections.remove(fd);
  }
}
