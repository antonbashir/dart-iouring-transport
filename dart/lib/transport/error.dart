import 'dart:async';

import 'bindings.dart';
import 'buffers.dart';
import 'callbacks.dart';
import 'client/registry.dart';
import 'constants.dart';
import 'exception.dart';
import 'extensions.dart';
import 'server/registry.dart';

class TransportErrorHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportBindings _bindings;
  final TransportBuffers _inboundBuffers;
  final TransportBuffers _outboundBuffers;
  final TransportCallbacks _callbacks;

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
    if (!server.notifyConnectionData(fd, bufferId)) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    _inboundBuffers.release(bufferId);
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(bufferId, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyInboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleWrite(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (!server.notifyConnectionData(fd, bufferId)) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    _inboundBuffers.release(bufferId);
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(bufferId, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyInboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleReceiveMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(bufferId, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyInboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleSendMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
        ),
      );
      return;
    }
    _callbacks.notifyInboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyAccept()) return;
    server.reaccept();
  }

  void _handleConnect(int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyConnect()) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      return;
    }
    unawaited(client.close());
    if (result == -ECANCELED) {
      _callbacks.notifyConnectError(fd, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyConnectError(
        fd,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleClientReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundError(bufferId, TransportClosedException.forClient());
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyOutboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleFileReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyOutboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleWriteSendCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundError(bufferId, TransportClosedException.forClient());
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCancelledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyOutboundError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void handle(int result, int data, int fd, int event) {
    if (event == transportEventRead | transportEventClient || event == transportEventReceiveMessage | transportEventClient) {
      _handleClientReadReceiveCallbacks(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventRead | transportEventFile) {
      _handleFileReadReceiveCallbacks(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == transportEventWrite | transportEventClient || event == transportEventSendMessage | transportEventClient) {
      _handleWriteSendCallbacks(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == (transportEventRead | transportEventServer)) {
      _handleRead(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == (transportEventReceiveMessage | transportEventServer)) {
      _handleReceiveMessage(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == (transportEventWrite | transportEventServer)) {
      _handleWrite(((data >> 16) & 0xffff), fd, event, result);
      return;
    }
    if (event == (transportEventSendMessage | transportEventServer)) {
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
