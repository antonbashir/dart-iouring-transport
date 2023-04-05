import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:iouring_transport/transport/extensions.dart';

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
  late final int _inboundRingSize;
  late final int _outboundRingSize;

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
      _clientRegistry.shutdown();
      _bindings.transport_worker_destroy(_outboundWorkerPointer);
      _serverRegistry.shutdown();
      _bindings.transport_worker_destroy(_inboundWorkerPointer);
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
      this,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
    );
    _serversfactory = TransportServersFactory(
      _serverRegistry,
      _inboundWorkerPointer,
      _bindings,
      this,
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
    _activator.close();
  }

  void registerCallback(int id, Completer<int> completer) => _callbacks.putCustom(id, completer);

  @pragma(preferInlinePragma)
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
  void _handleOutboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_outboundRingSize, _outboundCqes, _outboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _outboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_outboundRing, 1);
      final event = data & 0xffff;
      if (event & transportEventAll != 0) {
        final fd = (data >> 32) & 0xffffffff;
        if ((result & 0xffff) == transportEventCustomCallback) {
          _callbacks.notifyCustom((result >> 16) & 0xffff, data);
          continue;
        }
        if (result < 0) {
          if (result == -EAGAIN || result == -ECONNREFUSED) {
            _handleRetryableError(data, fd, event);
            continue;
          }
          _handleUnhandledError(result, data, fd, event);
          continue;
        }
        switch (event) {
          case transportEventReadCallback:
          case transportEventReceiveMessageCallback:
            _handleReadAndReceiveMessageCallback((data >> 16) & 0xffff, result);
            continue;
          case transportEventWriteCallback:
          case transportEventSendMessageCallback:
            _handleWriteAndSendMessageCallback((data >> 16) & 0xffff, result);
            continue;
          case transportEventConnect:
            _handleConnect(fd);
            continue;
        }
      }
    }
  }

  @pragma(preferInlinePragma)
  void _handleInboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_inboundRingSize, _inboundCqes, _inboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _inboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_inboundRing, 1);
      final event = data & 0xffff;
      if (event & transportEventAll != 0) {
        final fd = (data >> 32) & 0xffffffff;
        if (result < 0) {
          if (result == -EAGAIN) {
            _handleRetryableError(data, fd, event);
            continue;
          }
          _handleUnhandledError(result, data, fd, event);
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
          case transportEventSendMessage:
            _handleWriteAndSendMessage((data >> 16) & 0xffff, fd);
            continue;
          case transportEventAccept:
            _handleAccept(fd, result);
            continue;
        }
      }
    }
  }

  @pragma(preferInlinePragma)
  void _handleRetryableError(int data, int fd, int event) {
    switch (event) {
      case transportEventRead:
        final bufferId = ((data >> 16) & 0xffff);
        _bindings.transport_worker_read(_inboundWorkerPointer, fd, bufferId, _inboundUsedBuffers[bufferId], transportEventRead);
        return;
      case transportEventWrite:
        final bufferId = ((data >> 16) & 0xffff);
        _bindings.transport_worker_write(_inboundWorkerPointer, fd, bufferId, _inboundUsedBuffers[bufferId], transportEventWrite);
        return;
      case transportEventReceiveMessage:
        final bufferId = ((data >> 16) & 0xffff);
        final server = _serverRegistry.getByServer(fd);
        _bindings.transport_worker_receive_message(
          _inboundWorkerPointer,
          fd,
          bufferId,
          server.pointer.ref.family,
          MSG_TRUNC,
          transportEventRead,
        );
        return;
      case transportEventSendMessage:
        final bufferId = ((data >> 16) & 0xffff);
        final server = _serverRegistry.getByServer(fd);
        _bindings.transport_worker_respond_message(
          _inboundWorkerPointer,
          fd,
          bufferId,
          server.pointer.ref.family,
          MSG_TRUNC,
          transportEventWrite,
        );
        return;
      case transportEventReadCallback:
        final bufferId = ((data >> 16) & 0xffff);
        _bindings.transport_worker_read(_outboundWorkerPointer, fd, bufferId, _outboundUsedBuffers[bufferId], transportEventReadCallback);
        return;
      case transportEventWriteCallback:
        final bufferId = ((data >> 16) & 0xffff);
        _bindings.transport_worker_write(_outboundWorkerPointer, fd, bufferId, _outboundUsedBuffers[bufferId], transportEventWriteCallback);
        return;
      case transportEventReceiveMessageCallback:
        final bufferId = ((data >> 16) & 0xffff);
        final client = _clientRegistry.get(fd);
        _bindings.transport_worker_receive_message(
          _outboundWorkerPointer,
          fd,
          bufferId,
          client.ref.family,
          MSG_TRUNC,
          transportEventRead,
        );
        return;
      case transportEventSendMessageCallback:
        final bufferId = ((data >> 16) & 0xffff);
        final client = _clientRegistry.get(fd);
        _bindings.transport_worker_respond_message(
          _outboundWorkerPointer,
          fd,
          bufferId,
          client.ref.family,
          MSG_TRUNC,
          transportEventWrite,
        );
        return;
      case transportEventAccept:
        _bindings.transport_worker_accept(_inboundWorkerPointer, _serverRegistry.getByServer(fd).pointer);
        return;
      case transportEventConnect:
        _bindings.transport_worker_connect(_outboundWorkerPointer, _clientRegistry.get(fd));
        return;
    }
  }

  @pragma(preferInlinePragma)
  void _handleUnhandledError(int result, int userData, int fd, int event) {
    switch (event) {
      case transportEventRead:
      case transportEventWrite:
        final server = _serverRegistry.getByClient(fd);
        if (!server.controller.hasListener) {
          _releaseInboundBuffer(((userData >> 16) & 0xffff));
          _bindings.transport_close_descritor(fd);
          return;
        }
        _releaseInboundBuffer(((userData >> 16) & 0xffff));
        _bindings.transport_close_descritor(fd);
        server.controller.addError(TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
        return;
      case transportEventReceiveMessage:
      case transportEventSendMessage:
        final server = _serverRegistry.getByServer(fd);
        if (!server.controller.hasListener) {
          _releaseInboundBuffer(((userData >> 16) & 0xffff));
          return;
        }
        _releaseInboundBuffer(((userData >> 16) & 0xffff));
        server.controller.addError(TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd));
        return;
      case transportEventAccept:
        _bindings.transport_worker_accept(_inboundWorkerPointer, _serverRegistry.getByServer(fd).pointer);
        return;
      case transportEventConnect:
        _bindings.transport_close_descritor(fd);
        _callbacks.notifyConnectError(
          fd,
          TransportException.forEvent(
            event,
            result,
            result.kernelErrorToString(_bindings),
            fd,
          ),
        );
        return;
      case transportEventReadCallback:
      case transportEventReceiveMessageCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        _releaseOutboundBuffer(((userData >> 16) & 0xffff));
        _bindings.transport_close_descritor(fd);
        _callbacks.notifyReadError(
          bufferId,
          TransportException.forEvent(
            event,
            result,
            result.kernelErrorToString(_bindings),
            fd,
            bufferId: bufferId,
          ),
        );
        return;
      case transportEventWriteCallback:
      case transportEventSendMessageCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        _releaseOutboundBuffer(((userData >> 16) & 0xffff));
        _bindings.transport_close_descritor(fd);
        _callbacks.notifyWriteError(
          bufferId,
          TransportException.forEvent(
            event,
            result,
            result.kernelErrorToString(_bindings),
            fd,
            bufferId: bufferId,
          ),
        );
        return;
    }
  }

  @pragma(preferInlinePragma)
  void _handleRead(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByClient(fd);
    _allocateInbound().then((newBufferId) => _bindings.transport_worker_read(_inboundWorkerPointer, fd, newBufferId, 0, transportEventRead));
    if (!server.controller.hasListener) {
      _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
      _bindings.transport_worker_read(_inboundWorkerPointer, fd, bufferId, 0, transportEventRead);
      return;
    }
    final buffer = _inboundBuffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    server.controller.add(TransportInboundPayload(
      bufferBytes.asTypedList(result),
      (answer) {
        _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
        bufferBytes.asTypedList(answer.length).setAll(0, answer);
        buffer.iov_len = answer.length;
        _bindings.transport_worker_write(_inboundWorkerPointer, fd, bufferId, 0, transportEventWrite);
      },
      () => _releaseInboundBuffer(bufferId),
    ));
  }

  @pragma(preferInlinePragma)
  void _handleReceiveMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.controller.hasListener) {
      _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
      _bindings.transport_worker_receive_message(
        _inboundWorkerPointer,
        fd,
        bufferId,
        server.pointer.ref.family,
        MSG_TRUNC,
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
        transportEventReceiveMessage,
      );
    });
    final buffer = _inboundBuffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    server.controller.add(TransportInboundPayload(
      bufferBytes.asTypedList(result),
      (answer) {
        _bindings.transport_worker_reuse_buffer(_inboundWorkerPointer, bufferId);
        bufferBytes.asTypedList(answer.length).setAll(0, answer);
        buffer.iov_len = answer.length;
        _bindings.transport_worker_respond_message(
          _inboundWorkerPointer,
          fd,
          bufferId,
          server.pointer.ref.family,
          MSG_TRUNC,
          transportEventSendMessage,
        );
        return;
      },
      () => _releaseInboundBuffer(bufferId),
    ));
  }

  @pragma(preferInlinePragma)
  void _handleWriteAndSendMessage(int bufferId, int fd) {
    _releaseInboundBuffer(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleReadAndReceiveMessageCallback(int bufferId, int result) {
    _callbacks.notifyRead(
      bufferId,
      TransportOutboundPayload(
        _outboundBuffers[bufferId].iov_base.cast<Uint8>().asTypedList(result),
        () => _releaseOutboundBuffer(bufferId),
      ),
    );
  }

  @pragma(preferInlinePragma)
  void _handleWriteAndSendMessageCallback(int bufferId, int result) {
    _releaseOutboundBuffer(bufferId);
    _callbacks.notifyWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleConnect(int fd) {
    _callbacks.notifyConnect(fd, _clientRegistry.createConnectedClient(fd));
  }

  @pragma(preferInlinePragma)
  void _handleAccept(int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    _serverRegistry.mapClient(fd, result);
    _bindings.transport_worker_accept(_inboundWorkerPointer, server.pointer);
    server.acceptor!(TransportInboundChannel(
      _inboundWorkerPointer,
      result,
      _bindings,
      _inboundBufferFinalizers,
      this,
      server.pointer,
    ));
  }

  @visibleForTesting
  void notifyCustom(int callback, int data) => _bindings.transport_worker_custom(_outboundWorkerPointer, callback, data);
}
