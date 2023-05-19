import 'dart:async';

import 'file/registry.dart';
import 'links.dart';
import 'bindings.dart';
import 'callbacks.dart';
import 'client/registry.dart';
import 'constants.dart';
import 'exception.dart';
import 'extensions.dart';
import 'server/registry.dart';

class TransportErrorHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportFileRegistry _fileRegistry;
  final TransportBindings _bindings;
  final TransportCallbacks _callbacks;
  final TransportLinks _links;

  TransportErrorHandler(
    this._serverRegistry,
    this._clientRegistry,
    this._fileRegistry,
    this._bindings,
    this._callbacks,
    this._links,
  );

  void _handleRead(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (server == null) return;
    if (!server.notifyConnection(fd)) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyInboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
        bufferId: bufferId,
      ),
    );
  }

  void _handleWrite(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (server == null) return;
    if (!server.notifyConnection(fd)) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    unawaited(server.closeConnection(fd));
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyInboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
        bufferId: bufferId,
      ),
    );
  }

  void _handleReceiveMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (server == null) return;
    if (!server.notify()) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyInboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
        bufferId: bufferId,
      ),
    );
  }

  void _handleSendMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (server == null) return;
    if (!server.notify()) {
      _callbacks.notifyInboundError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyInboundError(
        bufferId,
        TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId),
      );
      return;
    }
    _callbacks.notifyInboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
        bufferId: bufferId,
      ),
    );
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (server == null) return;
    if (!server.notify()) return;
    server.reaccept();
  }

  void _handleConnect(int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (client == null) return;
    if (!client.notify()) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      return;
    }
    unawaited(client.close());
    if (result == -ECANCELED) {
      _callbacks.notifyConnectError(fd, TransportCanceledException(event: TransportEvent.ofEvent(event)));
      return;
    }
    _callbacks.notifyConnectError(
      fd,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
      ),
    );
  }

  void _handleClientReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (client == null) return;
    if (!client.notify()) {
      _callbacks.notifyOutboundError(bufferId, TransportClosedException.forClient());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyOutboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
        bufferId: bufferId,
      ),
    );
  }

  void _handleFileReadCallback(int bufferId, int fd, int event, int result) {
    final file = _fileRegistry.get(fd);
    if (file == null) return;
    if (!file.notify()) {
      _callbacks.notifyOutboundError(bufferId, TransportClosedException.forFile());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyOutboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
        bufferId: bufferId,
      ),
    );
  }

  void _handleFileWriteCallback(int bufferId, int fd, int event, int result) {
    final file = _fileRegistry.get(fd);
    if (file == null) return;
    if (!file.notify()) {
      _callbacks.notifyOutboundError(bufferId, TransportClosedException.forFile());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyOutboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
      ),
    );
  }

  void _handleClientWriteSendCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    if (client == null) return;
    if (!client.notify()) {
      _callbacks.notifyOutboundError(bufferId, TransportClosedException.forClient());
      return;
    }
    if (result == -ECANCELED) {
      _callbacks.notifyOutboundError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
      return;
    }
    _callbacks.notifyOutboundError(
      bufferId,
      TransportInternalException(
        event: TransportEvent.ofEvent(event),
        code: result,
        message: result.kernelErrorToString(_bindings),
      ),
    );
  }

  void handle(int result, int data, int fd, int event) {
    var bufferId = ((data >> 16) & 0xffff);
    if (event & transportEventLink != 0) {
      bufferId = event & transportEventServer != 0 ? _links.getInbound(bufferId) : _links.getOutbound(bufferId);
      event &= ~transportEventLink;
    }
    if (event == transportEventRead | transportEventClient || event == transportEventReceiveMessage | transportEventClient) {
      _handleClientReadReceiveCallbacks(bufferId, fd, event, result);
      return;
    }
    if (event == transportEventWrite | transportEventClient || event == transportEventSendMessage | transportEventClient) {
      _handleClientWriteSendCallbacks(bufferId, fd, event, result);
      return;
    }
    if (event == (transportEventRead | transportEventServer)) {
      _handleRead(bufferId, fd, event, result);
      return;
    }
    if (event == (transportEventReceiveMessage | transportEventServer)) {
      _handleReceiveMessage(bufferId, fd, event, result);
      return;
    }
    if (event == (transportEventWrite | transportEventServer)) {
      _handleWrite(bufferId, fd, event, result);
      return;
    }
    if (event == (transportEventSendMessage | transportEventServer)) {
      _handleSendMessage(bufferId, fd, event, result);
      return;
    }
    if (event == transportEventRead | transportEventFile) {
      _handleFileReadCallback(bufferId, fd, event, result);
      return;
    }
    if (event == transportEventWrite | transportEventFile) {
      _handleFileWriteCallback(bufferId, fd, event, result);
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
