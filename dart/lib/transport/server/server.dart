import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../links.dart';
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
  final TransportLinks _links;
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
    this._links,
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

  Future<TransportPayload> readSingle(TransportChannel channel, {bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final completer = Completer();
    _callbacks.setInbound(bufferId, completer);
    channel.read(bufferId, _readTimeout, transportEventRead | transportEventServer);
    connection.pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then((_) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
  }

  Future<List<TransportPayload>> readMany(TransportChannel channel, int count, {bool submit = true}) async {
    final messages = <TransportPayload>[];
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < count - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setInbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    for (var index = 0; index < count - 1; index++) {
      channel.read(
        bufferIds[index],
        _readTimeout,
        transportEventRead | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setInbound(lastBufferId, completer);
    channel.read(
      lastBufferId,
      _readTimeout,
      transportEventRead | transportEventServer | transportEventLink,
    );
    connection.pending += count;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future;
    for (var bufferId in bufferIds) messages.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
    return messages;
  }

  Future<void> writeSingle(TransportChannel channel, Uint8List bytes, {bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _callbacks.setInbound(bufferId, completer);
    channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    connection.pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future;
  }

  Future<void> writeMany(TransportChannel channel, List<Uint8List> bytes, {bool submit = true}) async {
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setInbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    for (var index = 0; index < bytes.length - 1; index++) {
      channel.write(
        bytes[index],
        bufferIds[index],
        _writeTimeout,
        transportEventWrite | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setInbound(lastBufferId, completer);
    channel.write(
      bytes[bytes.length - 1],
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventServer | transportEventLink,
    );
    connection.pending += bytes.length;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future;
  }

  Future<TransportDatagramResponder> receiveSingleMessage(TransportChannel channel, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final completer = Completer();
    _callbacks.setInbound(bufferId, completer);
    channel.receiveMessage(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventServer);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then((_) => _payloadPool.getDatagramResponder(bufferId, _buffers.read(bufferId), this, channel));
  }

  Future<List<TransportDatagramResponder>> receiveManyMessages(TransportChannel channel, int count, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final messages = <TransportDatagramResponder>[];
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < count - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setInbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forServer();
    for (var index = 0; index < count - 1; index++) {
      channel.receiveMessage(
        bufferIds[index],
        pointer.ref.family,
        _readTimeout,
        flags,
        transportEventReceiveMessage | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setInbound(lastBufferId, completer);
    channel.receiveMessage(
      lastBufferId,
      pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventServer | transportEventLink,
    );
    _pending += count;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future;
    for (var bufferId in bufferIds) messages.add(_payloadPool.getDatagramResponder(bufferId, _buffers.read(bufferId), this, channel));
    return messages;
  }

  @pragma(preferInlinePragma)
  Future<void> respondSingleMessage(TransportChannel channel, int bufferId, Uint8List bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    if (_closing) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _callbacks.setInbound(bufferId, completer);
    final destination = _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId);
    channel.sendMessage(
      bytes,
      bufferId,
      pointer.ref.family,
      destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventServer,
    );
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future;
  }

  @pragma(preferInlinePragma)
  Future<void> respondManyMessages(TransportChannel channel, int bufferId, List<Uint8List> bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = <int>[];
    final lastBufferId = _buffers.get() ?? await _buffers.allocate();
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _links.setInbound(bufferId, lastBufferId);
      bufferIds.add(bufferId);
    }
    if (_closing) throw TransportClosedException.forServer();
    final destination = _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId);
    for (var index = 0; index < bytes.length - 1; index++) {
      channel.sendMessage(
        bytes[index],
        bufferIds[index],
        pointer.ref.family,
        destination,
        _writeTimeout,
        flags,
        transportEventSendMessage | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    bufferIds.add(lastBufferId);
    final completer = Completer();
    _callbacks.setInbound(lastBufferId, completer);
    channel.sendMessage(
      bytes[bytes.length - 1],
      lastBufferId,
      pointer.ref.family,
      destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventServer | transportEventLink,
    );
    _pending += bytes.length;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    await completer.future;
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
