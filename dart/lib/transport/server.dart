import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'registry.dart';
import 'bindings.dart';
import 'buffers.dart';
import 'callbacks.dart';
import 'channels.dart';
import 'communicator.dart';
import 'constants.dart';
import 'exception.dart';
import 'payload.dart';

class _TransportConnectionState {
  var active = true;
  var pending = 0;
  Completer<void> closer = Completer();
}

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final int readTimeout;
  final int writeTimeout;
  final Transportcallbacks callbacks;
  final TransportBuffers _buffers;
  final TransportServerRegistry _registry;

  late final int fd;

  var _active = true;
  bool get active => _active;

  final _closer = Completer();
  final _connections = <int, _TransportConnectionState>{};

  var _pending = 0;

  TransportServer(
    this.pointer,
    this._workerPointer,
    this._bindings,
    this.callbacks,
    this.readTimeout,
    this.writeTimeout,
    this._buffers,
    this._registry,
  );

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection communicator) onAccept) {
    callbacks.setAccept(fd, (channel) {
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

  Future<TransportInboundStreamPayload> read(TransportChannel channel) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!active) throw TransportCancelledException();
    if (!hasConnection(channel.fd)) throw TransportCancelledException();
    final completer = Completer<int>();
    callbacks.setInboundRead(bufferId, completer);
    channel.read(bufferId, readTimeout, transportEventRead);
    return completer.future.then(
      (length) => TransportInboundStreamPayload(
        _buffers.read(bufferId, length),
        () => _buffers.release(bufferId),
        (bytes) {
          if (!active) throw TransportCancelledException();
          _buffers.reuse(bufferId);
          final completer = Completer<void>();
          callbacks.setInboundWrite(bufferId, completer);
          channel.write(bytes, bufferId, writeTimeout, transportEventWrite);
          return completer.future;
        },
      ),
    );
  }

  Future<void> write(Uint8List bytes, TransportChannel channel) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!active) throw TransportCancelledException();
    if (!hasConnection(channel.fd)) throw TransportCancelledException();
    final completer = Completer<void>();
    callbacks.setInboundWrite(bufferId, completer);
    channel.write(bytes, bufferId, writeTimeout, transportEventWrite);
    return completer.future;
  }

  Future<TransportInboundDatagramPayload> receiveMessage(TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (!active) throw TransportCancelledException();
    final completer = Completer<int>();
    callbacks.setInboundRead(bufferId, completer);
    channel.receiveMessage(bufferId, pointer.ref.family, readTimeout, flags, transportEventReceiveMessage);
    _pending++;
    return completer.future.then((length) {
      final bytes = _buffers.read(bufferId, length);
      final sender = TransportInboundDatagramSender(
        this,
        channel,
        _buffers,
        bufferId,
        bytes,
      );
      return TransportInboundDatagramPayload(
        bytes,
        sender,
        () => _buffers.release(bufferId),
        (bytes, flags) {
          if (!active) throw TransportCancelledException();
          _buffers.reuse(bufferId);
          final completer = Completer<void>();
          callbacks.setInboundWrite(bufferId, completer);
          channel.respondMessage(bytes, bufferId, pointer.ref.family, writeTimeout, flags, transportEventSendMessage);
          _pending++;
          return completer.future;
        },
      );
    });
  }

  Future<void> sendMessage(Uint8List bytes, int senderInitalBufferId, TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    if (!active) throw TransportCancelledException();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    final completer = Completer<void>();
    callbacks.setInboundWrite(bufferId, completer);
    channel.sendMessage(
      bytes,
      bufferId,
      pointer.ref.family,
      _bindings.transport_worker_get_endpoint_address(_workerPointer, pointer.ref.family, senderInitalBufferId),
      writeTimeout,
      flags,
      transportEventSendMessage,
    );
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
  bool notifyConnection(int fd, int bufferId) {
    final connection = _connections[fd]!;
    connection.pending--;
    if (_active && connection.active) return true;
    if (!connection.active) connection.closer.complete();
    if (!_active && _pending == 0 && _connections.isEmpty) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool hasPending() => _pending > 0 || _connections.isNotEmpty;

  @pragma(preferInlinePragma)
  bool hasConnection(int fd) => _connections.containsKey(fd);

  Future<void> close() async {
    if (_active) {
      _active = false;
      _bindings.transport_worker_cancel_by_fd(_workerPointer, fd);
      _connections.keys.forEach((fd) => _bindings.transport_worker_cancel_by_fd(_workerPointer, fd));
      if (_pending > 0 || _connections.isNotEmpty) await _closer.future;
      _bindings.transport_close_descritor(pointer.ref.fd);
      _bindings.transport_server_destroy(pointer);
      _registry.removeServer(fd);
    }
  }

  Future<void> closeConnection(int fd) async {
    if (!_active) throw TransportCancelledException();
    final connection = _connections[fd];
    if (connection == null || !connection.active) return;
    connection.active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, fd);
    await connection.closer;
    _registry.removeConnection(fd);
  }
}
