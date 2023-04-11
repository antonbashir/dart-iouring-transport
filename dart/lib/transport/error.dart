import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'server.dart';
import 'state.dart';

class TransportErrorHandler {
  final TransportServerRegistry _serverRegistry;
  final TransportClientRegistry _clientRegistry;
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _inboundWorkerPointer;
  final Pointer<transport_worker_t> _outboundWorkerPointer;
  final Queue<Completer<int>> _inboundBufferFinalizers;
  final Queue<Completer<int>> _outboundBufferFinalizers;
  final TransportEventStates _eventStates;

  TransportErrorHandler(
    this._serverRegistry,
    this._clientRegistry,
    this._bindings,
    this._inboundWorkerPointer,
    this._outboundWorkerPointer,
    this._inboundBufferFinalizers,
    this._outboundBufferFinalizers,
    this._eventStates,
  );

  Future<int> _allocateInbound() async {
    var bufferId = _bindings.transport_worker_get_buffer(_inboundWorkerPointer);
    while (bufferId == transportBufferUsed) {
      final completer = Completer<int>();
      _inboundBufferFinalizers.add(completer);
      await completer.future;
      bufferId = _bindings.transport_worker_get_buffer(_inboundWorkerPointer);
    }
    return bufferId;
  }

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

  void _handleReadWrite(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByClient(fd);
    if (event == transportEventRead) _eventStates.resetInboundRead(bufferId);
    if (event == transportEventWrite) _eventStates.resetInboundWrite(bufferId);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    if (!server!.controller.hasListener) {
      _releaseInboundBuffer(bufferId);
      _bindings.transport_close_descritor(fd);
      _serverRegistry.removeClient(fd);
      return;
    }
    _releaseInboundBuffer(bufferId);
    _bindings.transport_close_descritor(fd);
    _serverRegistry.removeClient(fd);
    server.controller.addError(TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleReceiveMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    _eventStates.resetInboundRead(bufferId);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _allocateInbound().then((newBufferId) {
      _bindings.transport_worker_receive_message(
        _inboundWorkerPointer,
        fd,
        newBufferId,
        server!.pointer.ref.family,
        MSG_TRUNC,
        server.readTimeout,
        transportEventReceiveMessage,
      );
    });
    if (!server!.controller.hasListener) {
      _releaseInboundBuffer(bufferId);
      return;
    }
    _releaseInboundBuffer(bufferId);
    server.controller.addError(TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleSendMessage(int bufferId, int fd, int event, int result) {
    final server = _serverRegistry.getByServer(fd);
    _eventStates.resetInboundWrite(bufferId);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _releaseInboundBuffer(bufferId);
    server!.controller.addError(TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
  }

  void _handleAccept(int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null, null)) return;
    _bindings.transport_worker_accept(_inboundWorkerPointer, server!.pointer);
  }

  void _handleConnect(int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    _eventStates.resetConnect(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _eventStates.notifyConnectCallbackError(fd, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _clientRegistry.removeClient(fd);
    _eventStates.notifyConnectCallbackError(
      fd,
      TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd),
    );
    client!.onComplete();
  }

  void _handleReadReceiveCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    _eventStates.resetOutboundRead(bufferId);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _releaseOutboundBuffer(bufferId);
    _clientRegistry.removeClient(fd);
    _callbacks.notifyReadError(
      bufferId,
      TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd, bufferId: bufferId),
    );
    client!.onComplete();
  }

  void _handleWriteSendCallbacks(int bufferId, int fd, int event, int result) {
    final client = _clientRegistry.get(fd);
    _eventStates.resetOutboundWrite(bufferId);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _releaseOutboundBuffer(bufferId);
    _clientRegistry.removeClient(fd);
    _callbacks.notifyWriteError(
      bufferId,
      TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd, bufferId: bufferId),
    );
    client!.onComplete();
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
      _handleReadWrite(((data >> 16) & 0xffff), fd, event, result);
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