import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:iouring_transport/transport/state.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'client.dart';
import 'configuration.dart';
import 'constants.dart';
import 'exception.dart';
import 'server.dart';

class TransportRetryState {
  late Duration delay;
  late int count;
  final TransportRetryConfiguration configuration;
  final int offset;

  TransportRetryState(this.configuration, this.offset) {
    delay = configuration.initialDelay;
    count = 0;
  }

  @pragma(preferInlinePragma)
  void reset() {
    delay = configuration.initialDelay;
    count = 0;
  }

  @pragma(preferInlinePragma)
  void update(Duration delay, int count) {
    this.delay = delay;
    this.count = count;
  }
}

class TransportRetryHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _inboundWorkerPointer;
  final Pointer<transport_worker_t> _outboundWorkerPointer;
  final Queue<Completer<int>> _inboundBufferFinalizers;
  final Queue<Completer<int>> _outboundBufferFinalizers;
  final TransportEventStates _eventStates;

  TransportRetryHandler(
    this._serverRegistry,
    this._clientRegistry,
    this._bindings,
    this._inboundWorkerPointer,
    this._outboundWorkerPointer,
    this._inboundBufferFinalizers,
    this._outboundBufferFinalizers,
    this._eventStates,
  );

  @pragma(preferInlinePragma)
  void _releaseInboundBuffer(int bufferId) {
    _bindings.transport_worker_release_buffer(_inboundWorkerPointer, bufferId);
    if (_inboundBufferFinalizers.isNotEmpty) _inboundBufferFinalizers.removeLast().complete(bufferId);
  }

  @pragma(preferInlinePragma)
  void _releaseOutboundBuffer(int bufferId) {
    _bindings.transport_worker_release_buffer(_outboundWorkerPointer, bufferId);
    if (_outboundBufferFinalizers.isNotEmpty) _outboundBufferFinalizers.removeLast().complete(bufferId);
  }

  @pragma(preferInlinePragma)
  bool _ensureServerIsActive(TransportServer? server, int? bufferId, int? clientFd) {
    if (server == null) {
      if (bufferId != null) _releaseInboundBuffer(bufferId);
      if (clientFd != null) _serverRegistry.removeClient(clientFd);
      return false;
    }
    if (!server.active) {
      if (bufferId != null) _releaseInboundBuffer(bufferId);
      if (clientFd != null) _serverRegistry.removeClient(clientFd);
      _serverRegistry.removeServer(server.fd);
      return false;
    }
    return true;
  }

  @pragma(preferInlinePragma)
  bool _ensureClientIsActive(TransportClient? client, int? bufferId, int fd) {
    if (client == null) {
      if (bufferId != null) _releaseOutboundBuffer(bufferId);
      return false;
    }
    if (!client.active) {
      if (bufferId != null) _releaseOutboundBuffer(bufferId);
      _clientRegistry.removeClient(fd);
      return false;
    }
    return true;
  }

  Future<void> _handleRead(int bufferId, int fd) async {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) {
      _eventStates.resetInboundRead(bufferId);
      return;
    }
    if (!(await _eventStates.incrementInboundRead(bufferId, server!.retry))) {
      _releaseInboundBuffer(bufferId);
      _serverRegistry.removeClient(fd);
      server.controller.addError(TransportTimeoutException.forServer());
      return;
    }
    _bindings.transport_worker_read(
      _inboundWorkerPointer,
      fd,
      bufferId,
      _inboundUsedBuffers[bufferId],
      server.readTimeout,
      transportEventRead,
    );
  }

  Future<void> _handleWrite(int bufferId, int fd) async {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) {
      _eventStates.resetInboundWrite(bufferId);
      return;
    }
    if (!(await _eventStates.incrementInboundWrite(bufferId, server!.retry))) {
      _releaseInboundBuffer(bufferId);
      _serverRegistry.removeClient(fd);
      server.controller.addError(TransportTimeoutException.forServer());
      return;
    }
    _bindings.transport_worker_write(
      _inboundWorkerPointer,
      fd,
      bufferId,
      _inboundUsedBuffers[bufferId],
      server.writeTimeout,
      transportEventWrite,
    );
  }

  Future<void> _handleReceiveMessage(int bufferId, int fd) async {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) {
      _eventStates.resetInboundRead(bufferId);
      return;
    }
    if (!(await _eventStates.incrementInboundRead(bufferId, server!.retry))) {
      _releaseInboundBuffer(bufferId);
      server.controller.addError(TransportTimeoutException.forServer());
      return;
    }
    _bindings.transport_worker_receive_message(
      _inboundWorkerPointer,
      fd,
      bufferId,
      server.pointer.ref.family,
      MSG_TRUNC,
      server.readTimeout,
      transportEventRead,
    );
  }

  Future<void> _handleSendMessage(int bufferId, int fd) async {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) {
      _eventStates.resetInboundWrite(bufferId);
      return;
    }
    if (!(await _eventStates.incrementInboundWrite(bufferId, server!.retry))) {
      _releaseInboundBuffer(bufferId);
      server.controller.addError(TransportTimeoutException.forServer());
      return;
    }
    _bindings.transport_worker_respond_message(
      _inboundWorkerPointer,
      fd,
      bufferId,
      server.pointer.ref.family,
      MSG_TRUNC,
      server.writeTimeout,
      transportEventWrite,
    );
  }

  Future<void> _handleReadCallback(int bufferId, int fd) async {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      _eventStates.resetOutboundRead(bufferId);
      return;
    }
    if (!(await _eventStates.incrementOutboundRead(bufferId, client!.retry))) {
      _releaseOutboundBuffer(bufferId);
      _clientRegistry.removeClient(fd);
      _callbacks.notifyReadError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _bindings.transport_worker_read(
      _outboundWorkerPointer,
      fd,
      bufferId,
      _outboundUsedBuffers[bufferId],
      client.readTimeout,
      transportEventRead | transportEventClient,
    );
  }

  Future<void> _handleWriteCallback(int bufferId, int fd) async {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      _eventStates.resetOutboundWrite(bufferId);
      return;
    }
    if (!(await _eventStates.incrementOutboundWrite(bufferId, client!.retry))) {
      _releaseOutboundBuffer(bufferId);
      _clientRegistry.removeClient(fd);
      _callbacks.notifyWriteError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _bindings.transport_worker_write(
      _outboundWorkerPointer,
      fd,
      bufferId,
      _outboundUsedBuffers[bufferId],
      client.writeTimeout,
      transportEventWrite | transportEventClient,
    );
    return;
  }

  Future<void> _handleReceiveMessageCallback(int bufferId, int fd) async {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      _eventStates.resetOutboundRead(bufferId);
      return;
    }
    if (!(await _eventStates.incrementOutboundRead(bufferId, client!.retry))) {
      _releaseOutboundBuffer(bufferId);
      _clientRegistry.removeClient(fd);
      _callbacks.notifyReadError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _bindings.transport_worker_receive_message(
      _outboundWorkerPointer,
      fd,
      bufferId,
      client.pointer.ref.family,
      MSG_TRUNC,
      client.readTimeout,
      transportEventRead | transportEventClient,
    );
  }

  Future<void> _handleSendMessageCallback(int bufferId, int fd) async {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client!.onComplete();
      _eventStates.resetOutboundWrite(bufferId);
      return;
    }
    if (!(await _eventStates.incrementOutboundWrite(bufferId, client!.retry))) {
      _releaseOutboundBuffer(bufferId);
      _clientRegistry.removeClient(fd);
      _callbacks.notifyWriteError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _bindings.transport_worker_respond_message(
      _outboundWorkerPointer,
      fd,
      bufferId,
      client.pointer.ref.family,
      MSG_TRUNC,
      client.writeTimeout,
      transportEventWrite | transportEventClient,
    );
    return;
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null, null)) return;
    _bindings.transport_worker_accept(_inboundWorkerPointer, server!.pointer);
  }

  Future<void> _handleConnect(int fd) async {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      client?.onComplete();
      _eventStates.resetConnect(fd);
      return;
    }
    if (!(await _eventStates.incrementConnect(fd, client!.retry))) {
      _clientRegistry.removeClient(fd);
      _callbacks.notifyConnectError(fd, TransportTimeoutException.forClient());
      return;
    }
    _bindings.transport_worker_connect(_outboundWorkerPointer, client.pointer, client.connectTimeout);
  }

  Future<void> handle(int data, int fd, int event, int result) async {
    if (event & transportEventClient != 0) {
      if (event & transportEventRead != 0) {
        _handleReadCallback(((data >> 16) & 0xffff), fd);
        return;
      }
      if (event & transportEventWrite != 0) {
        _handleWriteCallback(((data >> 16) & 0xffff), fd);
        return;
      }
      if (event & transportEventReceiveMessage != 0) {
        _handleReceiveMessageCallback(((data >> 16) & 0xffff), fd);
        return;
      }
      if (event & transportEventSendMessage != 0) {
        _handleSendMessageCallback(((data >> 16) & 0xffff), fd);
        return;
      }
    }
    if (event & transportEventRead != 0) {
      _handleRead(((data >> 16) & 0xffff), fd);
      return;
    }
    if (event & transportEventWrite != 0) {
      _handleWrite(((data >> 16) & 0xffff), fd);
      return;
    }
    if (event & transportEventReceiveMessage != 0) {
      _handleReceiveMessage(((data >> 16) & 0xffff), fd);
      return;
    }
    if (event & transportEventSendMessage != 0) {
      _handleSendMessage(((data >> 16) & 0xffff), fd);
      return;
    }
    if (event & transportEventAccept != 0) {
      _handleAccept(fd);
      return;
    }
    if (event & transportEventConnect != 0) {
      _handleConnect(fd);
      return;
    }
  }
}
