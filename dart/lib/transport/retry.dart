import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'package:iouring_transport/transport/configuration.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'client.dart';
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
  final _readState = <int, _TransportRetryValues>{};
  final _writeState = <int, _TransportRetryValues>{};

  @pragma(preferInlinePragma)
  bool incrementConnect(int fd, TransportRetryConfiguration retry) {
    final current = _connectState[fd];
    if (current == null) {
      _connectState[fd] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) return false;
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _connectState[fd] = _TransportRetryValues(newDelay, current.count + 1);
    return true;
  }

  @pragma(preferInlinePragma)
  bool incrementRead(int bufferId, TransportRetryConfiguration retry) {
    final current = _readState[bufferId];
    if (current == null) {
      _readState[bufferId] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) return false;
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _readState[bufferId] = _TransportRetryValues(newDelay, current.count + 1);
    return true;
  }

  @pragma(preferInlinePragma)
  bool incrementWrite(int bufferId, TransportRetryConfiguration retry) {
    final current = _writeState[bufferId];
    if (current == null) {
      _writeState[bufferId] = _TransportRetryValues(retry.initialDelay, 1);
      return true;
    }
    if (current.count == retry.maxRetries) return false;
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    _writeState[bufferId] = _TransportRetryValues(newDelay, current.count + 1);
    return true;
  }

  @pragma(preferInlinePragma)
  void clearConnect(int fd) => _connectState.remove(fd);

  @pragma(preferInlinePragma)
  void clearRead(int bufferId) => _readState.remove(bufferId);

  @pragma(preferInlinePragma)
  void clearWrite(int bufferId) => _writeState.remove(bufferId);
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

  void _handleRead(int bufferId, int fd) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    if (!_retryState.incrementRead(bufferId, server!.retry)) {
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
      server.pointer.ref.read_timeout,
      transportEventRead,
    );
  }

  void _handleWrite(int bufferId, int fd) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    _bindings.transport_worker_write(
      _inboundWorkerPointer,
      fd,
      bufferId,
      _inboundUsedBuffers[bufferId],
      server!.pointer.ref.write_timeout,
      transportEventWrite,
    );
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
      server.pointer.ref.read_timeout,
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
      server.pointer.ref.write_timeout,
      transportEventWrite,
    );
  }

  void _handleReadCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _bindings.transport_worker_read(
      _outboundWorkerPointer,
      fd,
      bufferId,
      _outboundUsedBuffers[bufferId],
      client!.pointer.ref.read_timeout,
      transportEventRead | transportEventClient,
    );
  }

  void _handleWriteCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _bindings.transport_worker_write(
      _outboundWorkerPointer,
      fd,
      bufferId,
      _outboundUsedBuffers[bufferId],
      client!.pointer.ref.write_timeout,
      transportEventWrite | transportEventClient,
    );
    return;
  }

  void _handleReceiveMessageCallback(int bufferId, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _bindings.transport_worker_receive_message(
      _outboundWorkerPointer,
      fd,
      bufferId,
      client!.pointer.ref.family,
      MSG_TRUNC,
      client.pointer.ref.read_timeout,
      transportEventRead | transportEventClient,
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
      client.pointer.ref.write_timeout,
      transportEventWrite | transportEventClient,
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
      client?.onComplete();
      return;
    }
    _bindings.transport_worker_connect(_outboundWorkerPointer, client!.pointer, client.pointer.ref.connect_timeout);
  }

  void handle(int data, int fd, int event, int result) {
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
