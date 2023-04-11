import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/extensions.dart';

import 'bindings.dart';
import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'factory.dart';
import 'lookup.dart';
import 'payload.dart';
import 'error.dart';
import 'server.dart';
import 'package:meta/meta.dart';

import 'state.dart';

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
  late final TransportEventStates _eventStates;
  late final int _inboundRingSize;
  late final int _outboundRingSize;
  late final TransportErrorHandler _errorHandler;

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
    _eventStates = TransportEventStates();
    _clientRegistry = TransportClientRegistry(
      _eventStates,
      _outboundWorkerPointer,
      _bindings,
      _outboundBufferFinalizers,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
      _inboundWorkerPointer,
      _eventStates,
      _inboundBufferFinalizers,
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
      _eventStates,
    );
    await _initializer.future;
    _inboundRing = _inboundWorkerPointer.ref.ring;
    _outboundRing = _outboundWorkerPointer.ref.ring;
    _inboundCqes = _bindings.transport_allocate_cqes(_transportPointer.ref.inbound_worker_configuration.ref.ring_size);
    _outboundCqes = _bindings.transport_allocate_cqes(_transportPointer.ref.outbound_worker_configuration.ref.ring_size);
    _inboundBuffers = _inboundWorkerPointer.ref.buffers;
    _outboundBuffers = _outboundWorkerPointer.ref.buffers;
    _inboundRingSize = _transportPointer.ref.inbound_worker_configuration.ref.ring_size;
    _outboundRingSize = _transportPointer.ref.outbound_worker_configuration.ref.ring_size;
    _errorHandler = TransportErrorHandler(
      _serverRegistry,
      _clientRegistry,
      _bindings,
      _inboundWorkerPointer,
      _outboundWorkerPointer,
      _inboundBufferFinalizers,
      _outboundBufferFinalizers,
      _eventStates,
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

  void register(int id, Completer<int> completer) => _eventStates.setCustom(id, completer);

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

  void _handleOutboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_outboundRingSize, _outboundCqes, _outboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _outboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_outboundRing, 1);
      if ((result & 0xffff) == transportEventCustom) {
        _eventStates.notifyCustom((result >> 16) & 0xffff, data);
        continue;
      }
      final event = data & 0xffff;
      print("${event.transportEventToString()} worker = ${_inboundWorkerPointer.ref.id}, result = $result,  bid = ${((data >> 16) & 0xffff)}");
      if (event & transportEventAll != 0) {
        final fd = (data >> 32) & 0xffffffff;
        if (result < 0) {
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
    _eventStates.notifyInboundRead(bufferId);
  }

  void _handleReceiveMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _eventStates.notifyInboundRead(bufferId);
  }

  void _handleWrite(int bufferId, int fd) {
    final server = _serverRegistry.getByClient(fd);
    if (!_ensureServerIsActive(server, bufferId, fd)) return;
    _releaseInboundBuffer(bufferId);
    _eventStates.notifyInboundWrite(bufferId);
  }

  void _handleSendMessage(int bufferId, int fd) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId, null)) return;
    _releaseInboundBuffer(bufferId);
    _eventStates.notifyInboundWrite(bufferId);
  }

  void _handleReadReceiveMessageCallback(int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _eventStates.notifyOutboundReadError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    client!.onComplete();
    _eventStates.notifyOutboundRead(
      bufferId,
      TransportOutboundPayload(
        _outboundBuffers[bufferId].iov_base.cast<Uint8>().asTypedList(result),
        () => _releaseOutboundBuffer(bufferId),
      ),
    );
  }

  void _handleWriteSendMessageCallback(int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _eventStates.notifyOutboundWriteError(bufferId, TransportClosedException.forClient());
      client?.onComplete();
      return;
    }
    _releaseOutboundBuffer(bufferId);
    client!.onComplete();
    _eventStates.notifyOutboundWrite(bufferId);
  }

  void _handleConnect(int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _eventStates.notifyConnectError(fd, TransportClosedException.forClient());
      return;
    }
    client!.onComplete();
    _eventStates.notifyConnect(fd, client);
  }

  void _handleAccept(int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null, result)) return;
    _serverRegistry.addClient(fd, result);
    _bindings.transport_worker_accept(_inboundWorkerPointer, server!.pointer);
    _eventStates.notifyAccept(
      fd,
      TransportChannel(
        _inboundWorkerPointer,
        result,
        _bindings,
        _inboundBufferFinalizers,
      ),
    );
  }

  @visibleForTesting
  void notifyCustom(int callback, int data) => _bindings.transport_worker_custom(_outboundWorkerPointer, callback, data);
}
