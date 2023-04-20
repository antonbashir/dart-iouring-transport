import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

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
  var closing = false;
  var pending = 0;
  Completer<void> closer = Completer();
}

class TransportServer {
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final int readTimeout;
  final int writeTimeout;
  final TransportCallbacks callbacks;
  final TransportBuffers _buffers;
  final TransportServerRegistry _registry;

  var _active = true;
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;

  final _closer = Completer();
  final _connections = <int, _TransportConnectionState>{};

  var _pending = 0;

  late final String address;

  TransportServer(
    this.pointer,
    this._workerPointer,
    this._bindings,
    this.callbacks,
    this.readTimeout,
    this.writeTimeout,
    this._buffers,
    this._registry,
  ) {
    address = _computeSourceAddress();
  }

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection communicator) onAccept) {
    if (_closing) throw TransportClosedException.forServer(address, unknown);
    callbacks.setAccept(pointer.ref.fd, (channel) {
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
    if (_closing) throw TransportClosedException.forServer(address, computeStreamAddress(channel.fd));
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer(address, computeStreamAddress(channel.fd));
    final completer = Completer<int>();
    callbacks.setInboundRead(bufferId, completer);
    channel.read(bufferId, readTimeout, transportEventRead);
    connection.pending++;
    return completer.future.then(
      (length) => TransportInboundStreamPayload(
        _buffers.read(bufferId, length),
        () => _buffers.release(bufferId),
        (bytes) {
          if (!active) throw TransportClosedException.forServer(address, computeStreamAddress(channel.fd));
          if (!connection.active) throw TransportClosedException.forServer(address, computeStreamAddress(channel.fd));
          _buffers.reuse(bufferId);
          final completer = Completer<void>();
          callbacks.setInboundWrite(bufferId, completer);
          channel.write(bytes, bufferId, writeTimeout, transportEventWrite);
          connection.pending++;
          return completer.future;
        },
      ),
    );
  }

  Future<void> write(Uint8List bytes, TransportChannel channel) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer(address, computeStreamAddress(channel.fd));
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer(address, computeStreamAddress(channel.fd));
    final completer = Completer<void>();
    callbacks.setInboundWrite(bufferId, completer);
    channel.write(bytes, bufferId, writeTimeout, transportEventWrite);
    connection.pending++;
    return completer.future;
  }

  Future<TransportInboundDatagramPayload> receiveMessage(TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer(address, unknown);
    final completer = Completer<int>();
    callbacks.setInboundRead(bufferId, completer);
    channel.receiveMessage(bufferId, pointer.ref.family, readTimeout, flags, transportEventReceiveMessage);
    _pending++;
    return completer.future.then((length) {
      final bytes = _buffers.read(bufferId, length);
      final sender = TransportServerDatagramSender(
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
        (bytes, {int? flags}) {
          if (_closing) throw TransportClosedException.forServer(address, computeDatagramAddress(bufferId));
          _buffers.reuse(bufferId);
          final completer = Completer<void>();
          callbacks.setInboundWrite(bufferId, completer);
          channel.respondMessage(bytes, bufferId, pointer.ref.family, writeTimeout, flags ?? TransportDatagramMessageFlag.trunc.flag, transportEventSendMessage);
          _pending++;
          return completer.future;
        },
      );
    });
  }

  Future<void> sendMessage(Uint8List bytes, int senderInitalBufferId, TransportChannel channel, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    if (_closing) throw TransportClosedException.forServer(address, computeDatagramAddress(senderInitalBufferId));
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    final completer = Completer<void>();
    callbacks.setInboundWrite(bufferId, completer);
    channel.sendMessage(
      bytes,
      bufferId,
      pointer.ref.family,
      _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, senderInitalBufferId),
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
    _buffers.release(bufferId);
    if (!connection.active && connection.pending == 0) connection.closer.complete();
    if (!_closing && _pending == 0 && _connections.isEmpty) _closer.complete();
    return false;
  }

  @pragma(preferInlinePragma)
  bool hasPending() => _pending > 0 || _connections.isNotEmpty;

  @pragma(preferInlinePragma)
  bool connectionIsActive(int fd) => _connections[fd]?.active == true;

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

  @pragma(preferInlinePragma)
  String computeStreamAddress(int fd) {
    final address = _bindings.transport_socket_fd_to_address(fd, pointer.ref.family);
    if (address == nullptr) return unknown;
    try {
      final addressString = address.cast<Utf8>().toDartString();
      malloc.free(address);
      if (pointer.ref.family == transport_socket_family.UNIX) return addressString;
      return "$addressString:${_bindings.transport_socket_fd_to_port(fd)}";
    } catch (_) {
      return unknown;
    }
  }

  @pragma(preferInlinePragma)
  String computeDatagramAddress(int bufferId) {
    final endpointAddress = _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId);
    final address = _bindings.transport_address_to_string(endpointAddress, pointer.ref.family);
    if (address == nullptr) return unknown;
    try {
      final addressString = address.cast<Utf8>().toDartString();
      malloc.free(address);
      if (pointer.ref.family == transport_socket_family.UNIX) return addressString;
      return "$addressString:${endpointAddress.cast<sockaddr_in>().ref.sin_port}";
    } catch (_) {
      return unknown;
    }
  }

  @pragma(preferInlinePragma)
  String _computeSourceAddress() {
    final address = _bindings.transport_server_address_to_string(pointer);
    final addressString = address.cast<Utf8>().toDartString();
    malloc.free(address);
    if (pointer.ref.family == transport_socket_family.UNIX) return addressString;
    return "$addressString:${pointer.ref.inet_server_address.sin_port}";
  }
}
