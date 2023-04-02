import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'callbacks.dart';
import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'factory.dart';
import 'logger.dart';
import 'lookup.dart';
import 'payload.dart';
import 'server.dart';

class TransportWorker {
  final _initializer = Completer();
  final _fromTransport = ReceivePort();
  final _bufferFinalizers = Queue<Completer<int>>();

  late final TransportLogger logger;
  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transportPointer;
  late final Pointer<transport_worker_t> _workerPointer;
  late final Pointer<io_uring> _ring;
  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;
  late final Pointer<msghdr> _inetUsedMessages;
  late final Pointer<msghdr> _unixUsedMessages;
  late final Pointer<Pointer<io_uring_cqe>> _cqes;
  late final RawReceivePort _listener;
  late final RawReceivePort _activator;
  late final RawReceivePort _closer;
  late final TransportClientRegistry _clientRegistry;
  late final TransportServerRegistry _serverRegistry;
  late final TransportClientsFactory _clientsfactory;
  late final TransportServersFactory _serversfactory;
  late final TransportFilesFactory _filesfactory;
  late final TransportCallbacks _callbacks;
  late int _ringSize;

  late final SendPort? transmitter;

  int get id => _workerPointer.ref.id;
  TransportServersFactory get servers => _serversfactory;
  TransportClientsFactory get clients => _clientsfactory;
  TransportFilesFactory get files => _filesfactory;

  TransportWorker(SendPort toTransport) {
    _listener = RawReceivePort((_) {
      final cqeCount = _bindings.transport_worker_peek(_ringSize, _cqes, _ring);
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = _cqes[cqeIndex];
        final data = cqe.ref.user_data;
        final result = cqe.ref.res;
        _bindings.transport_cqe_advance(_ring, 1);
        final event = data & 0xffff;
        if (event & transportEventAll != 0) {
          if (event == transportEventCustomCallback) {
            _callbacks.notifyCustom(result, data);
            continue;
          }
          final fd = (data >> 32) & 0xffffffff;
          if (result < 0) {
            _handleError(result, data, fd, event);
            continue;
          }
          //logger.debug("${event.transportEventToString()} worker = ${_workerPointer.ref.id}, result = $result, fd = $fd, bid = ${((data >> 16) & 0xffff)}");
          switch (event) {
            case transportEventRead:
              _handleRead((data >> 16) & 0xffff, fd, result);
              continue;
            case transportEventReceiveMessage:
              _handleReceiveMessage((data >> 16) & 0xffff, fd, result);
              continue;
            case transportEventWrite:
            case transportEventSendMessage:
              _handleWriteAndSendMessage((data >> 16) & 0xffff);
              continue;
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
            case transportEventAccept:
              _handleAccept(fd, result);
              continue;
          }
        }
      }
    });
    _activator = RawReceivePort((_) => _initializer.complete());
    _closer = RawReceivePort((_) async {
      _listener.close();
      _closer.close();
      _serverRegistry.shutdown();
      _clientRegistry.shutdown();
      _bindings.transport_worker_destroy(_workerPointer);
      Isolate.exit();
    });
    toTransport.send([_fromTransport.sendPort, _listener.sendPort, _activator.sendPort, _closer.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    _workerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_worker_t>();
    transmitter = configuration[3] as SendPort?;
    _fromTransport.close();
    logger = TransportLogger(TransportLogLevel.values[_transportPointer.ref.transport_configuration.ref.log_level]);
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _callbacks = TransportCallbacks();
    _clientRegistry = TransportClientRegistry(
      _callbacks,
      _transportPointer,
      _workerPointer,
      _bindings,
      _bufferFinalizers,
      this,
    );
    _serverRegistry = TransportServerRegistry(
      _transportPointer.ref.server_configuration,
      _bindings,
    );
    _serversfactory = TransportServersFactory(
      _serverRegistry,
      _workerPointer,
      _bindings,
      this,
      _bufferFinalizers,
    );
    _clientsfactory = TransportClientsFactory(
      _clientRegistry,
      _workerPointer,
      _bindings,
      this,
      _bufferFinalizers,
    );
    _filesfactory = TransportFilesFactory(
      _workerPointer,
      _bindings,
      this,
      _bufferFinalizers,
      _callbacks,
    );
    await _initializer.future;
    _ring = _workerPointer.ref.ring;
    _cqes = _bindings.transport_allocate_cqes(_transportPointer.ref.worker_configuration.ref.ring_size);
    _usedBuffers = _workerPointer.ref.used_buffers;
    _buffers = _workerPointer.ref.buffers;
    _inetUsedMessages = _workerPointer.ref.inet_used_messages;
    _unixUsedMessages = _workerPointer.ref.unix_used_messages;
    _ringSize = _transportPointer.ref.worker_configuration.ref.ring_size;
    _activator.close();
  }

  void registerCallback(int id, Completer<int> completer) => _callbacks.putCustom(id, completer);

  @pragma(preferInlinePragma)
  Future<int> _allocate() async {
    var bufferId = _bindings.transport_worker_select_buffer(_workerPointer);
    while (bufferId == -1) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      bufferId = await completer.future;
      if (_usedBuffers[bufferId] == transportBufferAvailable) return bufferId;
      bufferId = _bindings.transport_worker_select_buffer(_workerPointer);
    }
    return bufferId;
  }

  @pragma(preferInlinePragma)
  Future<void> _handleError(int result, int userData, int fd, int event) async {
    logger.debug("[error]: ${TransportException.forEvent(event, result, result.kernelErrorToString(_bindings), fd).message}, bid = ${((userData >> 16) & 0xffff)}");

    switch (event) {
      case transportEventRead:
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_read(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventRead);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _bindings.transport_close_descritor(fd);
        return;
      case transportEventWrite:
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_write(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventWrite);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        _bindings.transport_close_descritor(fd);
        return;
      case transportEventReceiveMessage:
        final bufferId = ((userData >> 16) & 0xffff);
        final server = _serverRegistry.getByServer(fd);
        if (result == -EAGAIN) {
          _bindings.transport_worker_receive_message(
            _workerPointer,
            fd,
            bufferId,
            server.pointer.ref.family,
            MSG_TRUNC,
            transportEventRead,
          );
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        return;
      case transportEventSendMessage:
        final bufferId = ((userData >> 16) & 0xffff);
        final server = _serverRegistry.getByServer(fd);
        if (result == -EAGAIN) {
          _bindings.transport_worker_respond_message(
            _workerPointer,
            fd,
            bufferId,
            server.pointer.ref.family,
            MSG_TRUNC,
            transportEventWrite,
          );
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        return;
      case transportEventAccept:
        _bindings.transport_worker_accept(_workerPointer, _serverRegistry.getByServer(fd).pointer);
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
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_read(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventReadCallback);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
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
        final bufferId = ((userData >> 16) & 0xffff);
        if (result == -EAGAIN) {
          _bindings.transport_worker_write(_workerPointer, fd, bufferId, _usedBuffers[bufferId], transportEventWriteCallback);
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
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
      case transportEventReceiveMessageCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        final client = _clientRegistry.get(fd);
        if (result == -EAGAIN) {
          _bindings.transport_worker_receive_message(
            _workerPointer,
            fd,
            bufferId,
            client.ref.family,
            MSG_TRUNC,
            transportEventRead,
          );
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
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
      case transportEventSendMessageCallback:
        final bufferId = ((userData >> 16) & 0xffff);
        final client = _clientRegistry.get(fd);
        if (result == -EAGAIN) {
          _bindings.transport_worker_respond_message(
            _workerPointer,
            fd,
            bufferId,
            client.ref.family,
            MSG_TRUNC,
            transportEventWrite,
          );
          return;
        }
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
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
  Future<void> _handleRead(int bufferId, int fd, int result) async {
    final server = _serverRegistry.getByClient(fd);
    if (!server.controller.hasListener) {
      logger.debug("[server]: stream hasn't listeners for fd = $fd");
      _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
      _bindings.transport_worker_read(_workerPointer, fd, bufferId, 0, transportEventRead);
      return;
    }
    _allocate().then((newBufferId) => _bindings.transport_worker_read(_workerPointer, fd, newBufferId, 0, transportEventRead));
    final buffer = _buffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    server.controller.add(TransportInboundPayload(
      bufferBytes.asTypedList(result),
      (answer) {
        _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
        bufferBytes.asTypedList(answer.length).setAll(0, answer);
        buffer.iov_len = answer.length;
        _bindings.transport_worker_write(_workerPointer, fd, bufferId, 0, transportEventWrite);
      },
      () {
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
      },
    ));
  }

  @pragma(preferInlinePragma)
  Future<void> _handleReceiveMessage(int bufferId, int fd, int result) async {
    final server = _serverRegistry.getByServer(fd);
    if (!server.controller.hasListener) {
      logger.debug("[server]: stream hasn't listeners for fd = $fd");
      _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
      _bindings.transport_worker_receive_message(
        _workerPointer,
        fd,
        bufferId,
        server.pointer.ref.family,
        MSG_TRUNC,
        transportEventReceiveMessage,
      );
      return;
    }
    _allocate().then((newBufferId) {
      _bindings.transport_worker_receive_message(
        _workerPointer,
        fd,
        newBufferId,
        server.pointer.ref.family,
        MSG_TRUNC,
        transportEventReceiveMessage,
      );
    });
    final buffer = _buffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    server.controller.add(TransportInboundPayload(
      bufferBytes.asTypedList(result),
      (answer) {
        _bindings.transport_worker_reuse_buffer(_workerPointer, bufferId);
        bufferBytes.asTypedList(answer.length).setAll(0, answer);
        buffer.iov_len = answer.length;
        _bindings.transport_worker_respond_message(
          _workerPointer,
          fd,
          bufferId,
          server.pointer.ref.family,
          MSG_TRUNC,
          transportEventSendMessage,
        );
        return;
      },
      () {
        _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
        if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
      },
    ));
  }

  @pragma(preferInlinePragma)
  Future<void> _handleWriteAndSendMessage(int bufferId) async {
    _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
    if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
  }

  @pragma(preferInlinePragma)
  Future<void> _handleReadAndReceiveMessageCallback(int bufferId, int result) async {
    _callbacks.notifyRead(
      bufferId,
      TransportOutboundPayload(
        _buffers[bufferId].iov_base.cast<Uint8>().asTypedList(result),
        () {
          _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
          if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
        },
      ),
    );
  }

  @pragma(preferInlinePragma)
  Future<void> _handleWriteAndSendMessageCallback(int bufferId, int result) async {
    _bindings.transport_worker_free_buffer(_workerPointer, bufferId);
    if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeLast().complete(bufferId);
    _callbacks.notifyWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  Future<void> _handleConnect(int fd) async {
    _callbacks.notifyConnect(fd, _clientRegistry.createConnectedClient(fd));
  }

  @pragma(preferInlinePragma)
  Future<void> _handleAccept(int fd, int result) async {
    final server = _serverRegistry.getByServer(fd);
    _serverRegistry.mapClient(fd, result);
    _bindings.transport_worker_accept(_workerPointer, server.pointer);
    server.acceptor!(TransportInboundChannel(
      _workerPointer,
      result,
      _bindings,
      _bufferFinalizers,
      this,
      server.pointer,
    ));
  }
}
