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
    if (!server.notifyConnection(fd, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer(server.address, server.computeStreamAddress(fd)));
      return;
    }
    _inboundBuffers.release(bufferId);
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundReadError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeStreamAddress(fd),
        ),
      );
      return;
    }
    _callbacks.notifyInboundReadError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeStreamAddress(fd),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleWrite(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (!server.notifyConnection(fd, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer(server.address, server.computeStreamAddress(fd)));
      return;
    }
    _inboundBuffers.release(bufferId);
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundWriteError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeStreamAddress(fd),
        ),
      );
      return;
    }
    _callbacks.notifyInboundWriteError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeStreamAddress(fd),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleReceiveMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer(server.address, server.computeDatagramAddress(bufferId)));
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundReadError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeDatagramAddress(bufferId),
        ),
      );
      return;
    }
    _callbacks.notifyInboundReadError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeDatagramAddress(bufferId),
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleSendMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer(server.address, server.computeDatagramAddress(bufferId)));
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyInboundWriteError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeDatagramAddress(bufferId),
        ),
      );
      return;
    }
    _callbacks.notifyInboundWriteError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: server.address,
          target: server.computeDatagramAddress(bufferId),
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
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient(client.destinationAddress, client.sourceAddress));
      return;
    }
    unawaited(client.close());
    if (result == -ECANCELED) {
      _callbacks.notifyConnectError(
        fd,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: client.sourceAddress,
          target: client.destinationAddress,
        ),
      );
      return;
    }
    _callbacks.notifyConnectError(
        fd,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: client.sourceAddress,
          target: client.destinationAddress,
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundReadError(bufferId, TransportClosedException.forClient(client.sourceAddress, client.destinationAddress));
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundReadError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: client.sourceAddress,
          target: client.destinationAddress,
        ),
      );
      return;
    }
    _callbacks.notifyOutboundReadError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: client.sourceAddress,
          target: client.destinationAddress,
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
  }

  void _handleWriteSendCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportClosedException.forClient(client.sourceAddress, client.destinationAddress));
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundWriteError(
        bufferId,
        TransportCancelledException(
          event: TransportEvent.ofEvent(event),
          source: client.sourceAddress,
          target: client.destinationAddress,
        ),
      );
      return;
    }
    _callbacks.notifyOutboundWriteError(
        bufferId,
        TransportInternalException(
          event: TransportEvent.ofEvent(event),
          source: client.sourceAddress,
          target: client.destinationAddress,
          code: result,
          message: result.kernelErrorToString(_bindings),
        ));
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
