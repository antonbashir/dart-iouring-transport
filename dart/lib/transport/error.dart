import 'dart:async';

import 'bindings.dart';
import 'buffers.dart';
import 'callbacks.dart';
import 'constants.dart';
import 'exception.dart';
import 'extensions.dart';
import 'registry.dart';

class TransportErrorHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportBindings _bindings;
  final TransportBuffers _inboundBuffers;
  final TransportBuffers _outboundBuffers;
  final Transportcallbacks _callbacks;

  TransportErrorHandler(
    this._serverRegistry,
    this._clientRegistry,
    this._bindings,
    this._inboundBuffers,
    this._outboundBuffers,
    this._callbacks,
  );

  void _handleRead(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (!server.notifyConnection(fd, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportCancelledException());
      return;
    }
    _inboundBuffers.release(bufferId);
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundReadError(bufferId, TransportCancelledException());
      return;
    }
    _callbacks.notifyInboundReadError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleWrite(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (!server.notifyConnection(fd, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportCancelledException());
      return;
    }
    _inboundBuffers.release(bufferId);
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundWriteError(bufferId, TransportCancelledException());
      return;
    }
    _callbacks.notifyInboundWriteError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleReceiveMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportCancelledException());
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundReadError(bufferId, TransportCancelledException());
      return;
    }
    _callbacks.notifyInboundReadError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleSendMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportCancelledException());
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundWriteError(bufferId, TransportCancelledException());
      return;
    }
    _callbacks.notifyInboundWriteError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyAccept()) return;
    server.reaccept();
  }

  void _handleConnect(int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyConnect()) {
      _callbacks.notifyConnectError(fd, TransportCancelledException());
      return;
    }
    unawaited(client.close());
    if (result == -ECANCELED) {
      _callbacks.notifyConnectError(fd, TransportCancelledException());
      return;
    }
    _callbacks.notifyConnectError(fd, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundReadError(bufferId, TransportCancelledException());
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundReadError(bufferId, TransportCancelledException());
      return;
    }
    _callbacks.notifyOutboundReadError(bufferId, TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd, bufferId: bufferId));
  }

  void _handleWriteSendCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportCancelledException());
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportCancelledException());
      return;
    }
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
