import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'bindings.dart';
import 'callbacks.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'server.dart';

class RetryHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _inboundWorkerPointer;
  final Pointer<transport_worker_t> _outboundWorkerPointer;
  final Pointer<Int64> _inboundUsedBuffers;
  final Pointer<Int64> _outboundUsedBuffers;
  final Queue<Completer<int>> _inboundBufferFinalizers;
  final Queue<Completer<int>> _outboundBufferFinalizers;
  final TransportCallbacks _callbacks;

  RetryHandler(
    this._serverRegistry,
    this._clientRegistry,
    this._bindings,
    this._inboundWorkerPointer,
    this._outboundWorkerPointer,
    this._inboundUsedBuffers,
    this._outboundUsedBuffers,
    this._inboundBufferFinalizers,
    this._outboundBufferFinalizers,
    this._callbacks,
  );

  void _releaseInboundBuffer(int bufferId) {
    _bindings.transport_worker_release_buffer(_inboundWorkerPointer, bufferId);
    if (_inboundBufferFinalizers.isNotEmpty) _inboundBufferFinalizers.removeLast().complete(bufferId);
  }

  void _releaseOutboundBuffer(int bufferId) {
    _bindings.transport_worker_release_buffer(_outboundWorkerPointer, bufferId);
    if (_outboundBufferFinalizers.isNotEmpty) _outboundBufferFinalizers.removeLast().complete(bufferId);
  }

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

  void _handleRead(int bufferId, int fd) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    _bindings.transport_worker_read(_inboundWorkerPointer, fd, bufferId, _inboundUsedBuffers[bufferId], transportEventRead);
  }

  void _handleWrite(int bufferId, int fd) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    _bindings.transport_worker_write(_inboundWorkerPointer, fd, bufferId, _inboundUsedBuffers[bufferId], transportEventWrite);
  }

  void _handleReceiveMessage(int bufferId, int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _bindings.transport_worker_receive_message(
      _inboundWorkerPointer,
      fd,
      bufferId,
      server!.pointer.ref.family,
      MSG_TRUNC,
      transportEventRead,
    );
  }

  void _handleSendMessage(int bufferId, int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _bindings.transport_worker_respond_message(
      _inboundWorkerPointer,
      fd,
      bufferId,
      server!.pointer.ref.family,
      MSG_TRUNC,
      transportEventWrite,
    );
  }

  void _handleReadCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client!.onComplete();
      return;
    }
    _bindings.transport_worker_read(_outboundWorkerPointer, fd, bufferId, _outboundUsedBuffers[bufferId], transportEventReadCallback);
  }

  void _handleWriteCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client!.onComplete();
      return;
    }
    _bindings.transport_worker_write(_outboundWorkerPointer, fd, bufferId, _outboundUsedBuffers[bufferId], transportEventWriteCallback);
    return;
  }

  void _handleReceiveMessageCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client!.onComplete();
      return;
    }
    _bindings.transport_worker_receive_message(
      _outboundWorkerPointer,
      fd,
      bufferId,
      client!.pointer.ref.family,
      MSG_TRUNC,
      transportEventRead,
    );
  }

  void _handleSendMessageCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client!.onComplete();
      return;
    }
    _bindings.transport_worker_respond_message(
      _outboundWorkerPointer,
      fd,
      bufferId,
      client!.pointer.ref.family,
      MSG_TRUNC,
      transportEventWrite,
    );
    return;
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null, null)) return;
    _bindings.transport_worker_accept(_inboundWorkerPointer, server!.pointer);
  }

  void _handleConnect(int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      client!.onComplete();
      return;
    }
    _bindings.transport_worker_connect(_outboundWorkerPointer, client!.pointer);
  }

  void handle(int data, int fd, int event) {
    switch (event) {
      case transportEventRead:
        _handleRead(((data >> 16) & 0xffff), fd);
        return;
      case transportEventWrite:
        _handleWrite(((data >> 16) & 0xffff), fd);
        return;
      case transportEventReceiveMessage:
        _handleReceiveMessage(((data >> 16) & 0xffff), fd);
        return;
      case transportEventSendMessage:
        _handleSendMessage(((data >> 16) & 0xffff), fd);
        return;
      case transportEventReadCallback:
        _handleReadCallback(((data >> 16) & 0xffff), fd);
        return;
      case transportEventWriteCallback:
        _handleWriteCallback(((data >> 16) & 0xffff), fd);
        return;
      case transportEventReceiveMessageCallback:
        _handleReceiveMessageCallback(((data >> 16) & 0xffff), fd);
        return;
      case transportEventSendMessageCallback:
        _handleSendMessageCallback(((data >> 16) & 0xffff), fd);
        return;
      case transportEventAccept:
        _handleAccept(fd);
        return;
      case transportEventConnect:
        _handleConnect(fd);
        return;
    }
  }
}
