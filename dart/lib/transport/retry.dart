import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'bindings.dart';
import 'callbacks.dart';
import 'client.dart';
import 'configuration.dart';
import 'constants.dart';
import 'exception.dart';
import 'server.dart';

class _TransportRetryValues {
  final Duration delay;
  final int count;

  const _TransportRetryValues(this.delay, this.count);
}

class TransportRetryStates {
  final _connectState = <int, _TransportRetryValues>{};
  final _inboundReadState = <int, _TransportRetryValues>{};
  final _inboundWriteState = <int, _TransportRetryValues>{};
  final _outboundReadState = <int, _TransportRetryValues>{};
  final _outboundWriteState = <int, _TransportRetryValues>{};

  Future<bool> incrementConnect(int fd, TransportRetryConfiguration retry) async {
    final current = _connectState[fd];
    if (current == null) {
      _connectState[fd] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) {
      _connectState.remove(fd);
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _connectState[fd] = _TransportRetryValues(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementInboundRead(int bufferId, TransportRetryConfiguration retry) async {
    final current = _inboundReadState[bufferId];
    if (current == null) {
      _inboundReadState[bufferId] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) {
      _inboundReadState.remove(bufferId);
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _inboundReadState[bufferId] = _TransportRetryValues(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementInboundWrite(int bufferId, TransportRetryConfiguration retry) async {
    final current = _inboundWriteState[bufferId];
    if (current == null) {
      _inboundWriteState[bufferId] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) {
      _inboundWriteState.remove(bufferId);
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _inboundWriteState[bufferId] = _TransportRetryValues(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementOutboundRead(int bufferId, TransportRetryConfiguration retry) async {
    final current = _outboundReadState[bufferId];
    if (current == null) {
      _outboundReadState[bufferId] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) {
      _outboundReadState.remove(bufferId);
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _outboundReadState[bufferId] = _TransportRetryValues(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementOutboundWrite(int bufferId, TransportRetryConfiguration retry) async {
    final current = _outboundWriteState[bufferId];
    if (current == null) {
      _outboundWriteState[bufferId] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) {
      _outboundWriteState.remove(bufferId);
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _outboundWriteState[bufferId] = _TransportRetryValues(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  @pragma(preferInlinePragma)
  void clearConnect(int fd) => _connectState.remove(fd);

  @pragma(preferInlinePragma)
  void clearInboundRead(int bufferId) => _inboundReadState.remove(bufferId);

  @pragma(preferInlinePragma)
  void clearInboundWrite(int bufferId) => _inboundWriteState.remove(bufferId);

  @pragma(preferInlinePragma)
  void clearOutboundRead(int bufferId) => _outboundReadState.remove(bufferId);

  @pragma(preferInlinePragma)
  void clearOutboundWrite(int bufferId) => _outboundWriteState.remove(bufferId);
}

class TransportRetryHandler {
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
  final TransportRetryStates _retryState;

  TransportRetryHandler(
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
    this._retryState,
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
      _retryState.clearInboundRead(bufferId);
      return;
    }
    if (!(await _retryState.incrementInboundRead(bufferId, server!.retry))) {
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
      _retryState.clearInboundWrite(bufferId);
      return;
    }
    if (!(await _retryState.incrementInboundWrite(bufferId, server!.retry))) {
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
      _retryState.clearInboundRead(bufferId);
      return;
    }
    if (!(await _retryState.incrementInboundRead(bufferId, server!.retry))) {
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
      _retryState.clearInboundWrite(bufferId);
      return;
    }
    if (!(await _retryState.incrementInboundWrite(bufferId, server!.retry))) {
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
      _retryState.clearOutboundRead(bufferId);
      return;
    }
    if (!(await _retryState.incrementOutboundRead(bufferId, client!.retry))) {
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
      _retryState.clearOutboundWrite(bufferId);
      return;
    }
    if (!(await _retryState.incrementOutboundWrite(bufferId, client!.retry))) {
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
      _retryState.clearOutboundRead(bufferId);
      return;
    }
    if (!(await _retryState.incrementOutboundRead(bufferId, client!.retry))) {
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
      _retryState.clearOutboundWrite(bufferId);
      return;
    }
    if (!(await _retryState.incrementOutboundWrite(bufferId, client!.retry))) {
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
      _retryState.clearConnect(fd);
      return;
    }
    if (!(await _retryState.incrementConnect(fd, client!.retry))) {
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
