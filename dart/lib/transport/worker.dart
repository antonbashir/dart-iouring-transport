import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';
import 'package:iouring_transport/transport/resilience.dart';
import 'package:iouring_transport/transport/retry.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'factory.dart';
import 'lookup.dart';
import 'payload.dart';
import 'server.dart';
import 'package:meta/meta.dart';

class TransportWorker {
  final _initializer = Completer();
  final _fromTransport = ReceivePort();
  final _inboundBufferFinalizers = Queue<Completer<int>>();
  final _outboundBufferFinalizers = Queue<Completer<int>>();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transportPointer;
  late final Pointer<transport_worker_t> _inboundWorkerPointer;
  late final Pointer<transport_worker_t> _outboundWorkerPointer;
  late final Pointer<io_uring> _inboundRing;
  late final Pointer<io_uring> _outboundRing;
  late final Pointer<Int64> _inboundUsedBuffers;
  late final Pointer<Int64> _outboundUsedBuffers;
  late final Pointer<iovec> _inboundBuffers;
  late final Pointer<iovec> _outboundBuffers;
  late final Pointer<Pointer<io_uring_cqe>> _inboundCqes;
  late final Pointer<Pointer<io_uring_cqe>> _outboundCqes;
  late final RawReceivePort _listener;
  late final RawReceivePort _activator;
  late final RawReceivePort _closer;
  late final TransportClientRegistry _clientRegistry;
  late final TransportServerRegistry _serverRegistry;
  late final TransportClientsFactory _clientsfactory;
  late final TransportServersFactory _serversfactory;
  late final TransportFilesFactory _filesfactory;
  late final TransportCallbacks _callbacks;
  late final TransportRetryStates _retryStates;
  late final int _inboundRingSize;
  late final int _outboundRingSize;
  late final ErrorHandler _errorHandler;
  late final TransportRetryHandler _retryHandler;

  late final SendPort? transmitter;

  int get id => _inboundWorkerPointer.ref.id;
  TransportServersFactory get servers => _serversfactory;
  TransportClientsFactory get clients => _clientsfactory;
  TransportFilesFactory get files => _filesfactory;

  TransportWorker(SendPort toTransport) {
    _listener = RawReceivePort((_) {
      _handleInboundCqes();
      _handleOutboundCqes();
    });
    _activator = RawReceivePort((_) => _initializer.complete());
    _closer = RawReceivePort((_) async {
      await _clientRegistry.close();
      await _serverRegistry.close();
      _bindings.transport_worker_destroy(_outboundWorkerPointer);
      malloc.free(_outboundCqes);
      _bindings.transport_worker_destroy(_inboundWorkerPointer);
      malloc.free(_inboundCqes);
      _listener.close();
      _closer.close();
      Isolate.exit();
    });
    toTransport.send([_fromTransport.sendPort, _listener.sendPort, _activator.sendPort, _closer.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    _inboundWorkerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_worker_t>();
    _outboundWorkerPointer = Pointer.fromAddress(configuration[3] as int).cast<transport_worker_t>();
    transmitter = configuration[4] as SendPort?;
    _fromTransport.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _callbacks = TransportCallbacks();
    _clientRegistry = TransportClientRegistry(
      _callbacks,
      _outboundWorkerPointer,
      _bindings,
      _outboundBufferFinalizers,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
      _inboundWorkerPointer,
    );
    _serversfactory = TransportServersFactory(
      _serverRegistry,
      _inboundWorkerPointer,
      _bindings,
      _inboundBufferFinalizers,
    );
    _clientsfactory = TransportClientsFactory(
      _clientRegistry,
    );
    _filesfactory = TransportFilesFactory(
      _outboundWorkerPointer,
      _bindings,
      this,
      _outboundBufferFinalizers,
      _callbacks,
    );
    await _initializer.future;
    _inboundRing = _inboundWorkerPointer.ref.ring;
    _outboundRing = _outboundWorkerPointer.ref.ring;
    _inboundCqes = _bindings.transport_allocate_cqes(_transportPointer.ref.inbound_worker_configuration.ref.ring_size);
    _outboundCqes = _bindings.transport_allocate_cqes(_transportPointer.ref.outbound_worker_configuration.ref.ring_size);
    _inboundUsedBuffers = _inboundWorkerPointer.ref.used_buffers;
    _outboundUsedBuffers = _outboundWorkerPointer.ref.used_buffers;
    _inboundBuffers = _inboundWorkerPointer.ref.buffers;
    _outboundBuffers = _outboundWorkerPointer.ref.buffers;
    _inboundRingSize = _transportPointer.ref.inbound_worker_configuration.ref.ring_size;
    _outboundRingSize = _transportPointer.ref.outbound_worker_configuration.ref.ring_size;
    _errorHandler = ErrorHandler(
      _serverRegistry,
      _clientRegistry,
      _bindings,
      _inboundWorkerPointer,
      _outboundWorkerPointer,
      _inboundUsedBuffers,
      _outboundUsedBuffers,
      _inboundBufferFinalizers,
      _outboundBufferFinalizers,
      _callbacks,
    );
    _retryHandler = TransportRetryHandler(
      _serverRegistry,
      _clientRegistry,
      _bindings,
      _inboundWorkerPointer,
      _outboundWorkerPointer,
      _inboundUsedBuffers,
      _outboundUsedBuffers,
      _inboundBufferFinalizers,
      _outboundBufferFinalizers,
      _callbacks,
      _retryStates,
    );
    _activator.close();
    Timer.periodic(Duration(seconds: 1), (timer) {
      final cqeCount = _bindings.transport_worker_peek(_inboundRingSize, _inboundCqes, _inboundRing);
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        print(_inboundCqes[cqeIndex].ref.res);
      }
      final ocqeCount = _bindings.transport_worker_peek(_outboundRingSize, _outboundCqes, _outboundRing);
      for (var cqeIndex = 0; cqeIndex < ocqeCount; cqeIndex++) {
        print(_outboundCqes[cqeIndex].ref.res);
      }
    });
  }

  void registerCallback(int id, Completer<int> completer) => _callbacks.putCustom(id, completer);

  Future<int> _allocateInbound() async {
    var bufferId = _bindings.transport_worker_select_buffer(_inboundWorkerPointer);
    while (bufferId == -1) {
      final completer = Completer<int>();
      _inboundBufferFinalizers.add(completer);
      bufferId = await completer.future;
      if (_inboundUsedBuffers[bufferId] == transportBufferAvailable) return bufferId;
      bufferId = _bindings.transport_worker_select_buffer(_inboundWorkerPointer);
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
  bool _errorIsRetryable(int error) => error == -EINTR || error == -EAGAIN || error == -EALREADY || error == -ECANCELED;

  void _handleOutboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_outboundRingSize, _outboundCqes, _outboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _outboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_outboundRing, 1);
      if ((result & 0xffff) == transportEventCustom) {
        _callbacks.notifyCustom((result >> 16) & 0xffff, data);
        continue;
      }
      final event = data & 0xffff;
      print("${event.transportEventToString()} worker = ${_inboundWorkerPointer.ref.id}, result = $result,  bid = ${((data >> 16) & 0xffff)}");
      if (event & transportEventAll != 0) {
        final fd = (data >> 32) & 0xffffffff;
        if (result < 0) {
          if (_errorIsRetryable(result)) {
            _retryHandler.handle(data, fd, event, result);
            continue;
          }
          _errorHandler.handle(result, data, fd, event);
          continue;
        }
        if (event == transportEventRead | transportEventClient || event == transportEventReceiveMessage | transportEventClient) {
          _handleReadReceiveMessageCallback((data >> 16) & 0xffff, result, fd);
          continue;
        }
        if (event == transportEventWrite | transportEventClient || event == transportEventSendMessage | transportEventClient) {
          _handleWriteSendMessageCallback((data >> 16) & 0xffff, result, fd);
          continue;
        }
        if (event & transportEventConnect != 0) {
          _handleConnect(fd);
          continue;
        }
      }
    }
  }

  void _handleInboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_inboundRingSize, _inboundCqes, _inboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _inboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_inboundRing, 1);
      final event = data & 0xffff;
      print("${event.transportEventToString()} worker = ${_inboundWorkerPointer.ref.id}, result = $result,  bid = ${((data >> 16) & 0xffff)}");
      if (event & transportEventAll != 0) {
        final fd = (data >> 32) & 0xffffffff;
        if (result < 0) {
          if (_errorIsRetryable(result)) {
            _retryHandler.handle(data, fd, event, result);
            continue;
          }
          _errorHandler.handle(result, data, fd, event);
          continue;
        }
        switch (event) {
          case transportEventRead:
            _handleRead((data >> 16) & 0xffff, fd, result);
            continue;
          case transportEventReceiveMessage:
            _handleReceiveMessage((data >> 16) & 0xffff, fd, result);
            continue;
          case transportEventWrite:
            _handleWrite((data >> 16) & 0xffff, fd);
            continue;
          case transportEventSendMessage:
            _handleSendMessage((data >> 16) & 0xffff, fd);
            continue;
          case transportEventAccept:
            _handleAccept(fd, result);
            continue;
        }
      }
    }
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

  void _handleRead(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    _allocateInbound().then(
      (newBufferId) => _bindings.transport_worker_read(
        _inboundWorkerPointer,
        fd,
        newBufferId,
        0,
        server!.pointer.ref.read_timeout,
        transportEventRead,
      ),
    );
    if (!server!.controller.hasListener) {
      _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
      _bindings.transport_worker_read(_inboundWorkerPointer, fd, bufferId, 0, server.pointer.ref.read_timeout, transportEventRead);
      return;
    }
    final buffer = _inboundBuffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    server.controller.add(TransportInboundPayload(
      bufferBytes.asTypedList(result),
      (answer) {
        if (!_ensureServerIsActive(server, bufferId, fd)) return;
        _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
        bufferBytes.asTypedList(answer.length).setAll(0, answer);
        buffer.iov_len = answer.length;
        _bindings.transport_worker_write(_inboundWorkerPointer, fd, bufferId, 0, server.pointer.ref.write_timeout, transportEventWrite);
      },
      () => _releaseInboundBuffer(bufferId),
    ));
  }

  void _handleReceiveMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    if (!server!.controller.hasListener) {
      _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
      _bindings.transport_worker_receive_message(
        _inboundWorkerPointer,
        fd,
        bufferId,
        server.pointer.ref.family,
        MSG_TRUNC,
        server.pointer.ref.read_timeout,
        transportEventReceiveMessage,
      );
      return;
    }
    _allocateInbound().then((newBufferId) {
      _bindings.transport_worker_receive_message(
        _inboundWorkerPointer,
        fd,
        newBufferId,
        server.pointer.ref.family,
        MSG_TRUNC,
        server.pointer.ref.read_timeout,
        transportEventReceiveMessage,
      );
    });
    final buffer = _inboundBuffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    server.controller.add(TransportInboundPayload(
      bufferBytes.asTypedList(result),
      (answer) {
        if (!_ensureServerIsActive(server, bufferId, null)) return;
        _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
        bufferBytes.asTypedList(answer.length).setAll(0, answer);
        buffer.iov_len = answer.length;
        _bindings.transport_worker_respond_message(
          _inboundWorkerPointer,
          fd,
          bufferId,
          server.pointer.ref.family,
          MSG_TRUNC,
          server.pointer.ref.write_timeout,
          transportEventSendMessage,
        );
        return;
      },
      () => _releaseInboundBuffer(bufferId),
    ));
  }

  void _handleWrite(int bufferId, int fd) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    _releaseInboundBuffer(bufferId);
  }

  void _handleSendMessage(int bufferId, int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _releaseInboundBuffer(bufferId);
  }

  void _handleReadReceiveMessageCallback(int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _callbacks.notifyRead(
      bufferId,
      TransportOutboundPayload(
        _outboundBuffers[bufferId].iov_base.cast<Uint8>().asTypedList(result),
        () => _releaseOutboundBuffer(bufferId),
      ),
    );
    client!.onComplete();
  }

  void _handleWriteSendMessageCallback(int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyWriteError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _releaseOutboundBuffer(bufferId);
    _callbacks.notifyWrite(bufferId);
    client!.onComplete();
  }

  void _handleConnect(int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      return;
    }
    _callbacks.notifyConnect(fd, client!);
    client.onComplete();
  }

  void _handleAccept(int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null, result)) return;
    _serverRegistry.addClient(fd, result);
    _bindings.transport_worker_accept(_inboundWorkerPointer, server!.pointer);
    server.acceptor!(TransportInboundChannel(
      _inboundWorkerPointer,
      result,
      _bindings,
      _inboundBufferFinalizers,
      server,
    ));
  }

  @visibleForTesting
  void notifyCustom(int callback, int data) => _bindings.transport_worker_custom(_outboundWorkerPointer, callback, data);
}
