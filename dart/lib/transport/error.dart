import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'server.dart';
import 'callbacks.dart';

class TransportErrorHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _inboundWorkerPointer;
  final Pointer<transport_worker_t> _outboundWorkerPointer;
  final Queue<Completer<int>> _inboundBufferFinalizers;
  final Queue<Completer<int>> _outboundBufferFinalizers;
  final Transportcallbacks _callbacks;

  TransportErrorHandler(
    this._serverRegistry,
    this._clientRegistry,
    this._bindings,
    this._inboundWorkerPointer,
    this._outboundWorkerPointer,
    this._inboundBufferFinalizers,
    this._outboundBufferFinalizers,
    this._callbacks,
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
  bool _ensureServerIsActive(TransportServer server, int? bufferId) {
    server.onComplete();
    if (!server.active) {
      if (bufferId != null) _releaseInboundBuffer(bufferId);
      if (!server.hasPending()) _serverRegistry.removeServer(server.fd);
      return false;
    }
    return true;
  }

  @pragma(preferInlinePragma)
  bool _ensureClientIsActive(TransportClient client, int? bufferId, int fd) {
    client.onComplete();
    if (!client.active) {
      if (bufferId != null) _releaseOutboundBuffer(bufferId);
      if (!client.hasPending()) _clientRegistry.removeClient(fd);
      return false;
    }
    return true;
  }

  void _handleRead(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByClient(fd);
    if (server == null) return;
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer());
      return;
    }
    _releaseInboundBuffer(bufferId);
    _bindings.transport_close_descritor(fd);
    //_serverRegistry.removeClient(fd);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundReadError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _callbacks.notifyInboundReadError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleWrite(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByClient(fd);
    if (server == null) return;
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer());
      return;
    }
    _releaseInboundBuffer(bufferId);
    _bindings.transport_close_descritor(fd);
    //_serverRegistry.removeClient(fd);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundWriteError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _callbacks.notifyInboundWriteError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleReceiveMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyInboundReadError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _releaseInboundBuffer(bufferId);
    _callbacks.notifyInboundReadError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleSendMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyInboundWriteError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _releaseInboundBuffer(bufferId);
    _callbacks.notifyInboundWriteError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null)) return;
    server.reaccept();
  }

  void _handleConnect(int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      return;
    }
    _clientRegistry.removeClient(fd);
    if (result == -ECANCELED) {
      _callbacks.notifyConnectError(fd, TransportTimeoutException.forClient());
      return;
    }
    _callbacks.notifyConnectError(fd, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyOutboundReadError(bufferId, TransportClosedException.forClient());
      return;
    }
    _releaseOutboundBuffer(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundReadError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _callbacks.notifyOutboundReadError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd, bufferId: bufferId));
  }

  void _handleWriteSendCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportClosedException.forClient());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _releaseOutboundBuffer(bufferId);
    _callbacks.notifyOutboundWriteError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd, bufferId: bufferId));
  }

  void handle(int result, int data, int fd, int event) {
    if (event == transportEventRead | transportEventClient || event == transportEventReceiveMessage | transportEventClient) {
      _handleReadReceiveCallbacks(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventWrite | transportEventClient || event == transportEventSendMessage | transportEventClient) {
      _handleWriteSendCallbacks(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventRead || event == transportEventWrite) {
      _handleRead(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventWrite) {
      _handleWrite(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventReceiveMessage) {
      _handleReceiveMessage(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventSendMessage) {
      _handleSendMessage(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventAccept) {
      _handleAccept(fd);
      return;
    }
    if (event == transportEventConnect) {
      _handleConnect(fd, event, result);
      return;
    }
  }
}
