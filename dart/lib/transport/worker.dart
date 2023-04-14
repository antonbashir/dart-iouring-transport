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
import 'error.dart';
import 'server.dart';
import 'package:meta/meta.dart';

import 'callbacks.dart';

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
  late final Transportcallbacks _callbacks;
  late final int _inboundRingSize;
  late final int _outboundRingSize;
  late final TransportErrorHandler _errorHandler;
  late final Timer _timeoutChecker;

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
      _timeoutChecker.cancel();
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
    await _initializer.future;
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _callbacks = Transportcallbacks(
      _inboundWorkerPointer.ref.buffers_count,
      _outboundWorkerPointer.ref.buffers_count,
    );
    _clientRegistry = TransportClientRegistry(
      _bindings,
      _callbacks,
      _outboundWorkerPointer,
      _outboundBufferFinalizers,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
      _callbacks,
      _inboundWorkerPointer,
      _inboundBufferFinalizers,
    );
    _serversfactory = TransportServersFactory(
      _bindings,
      _serverRegistry,
      _inboundWorkerPointer,
      _inboundBufferFinalizers,
    );
    _clientsfactory = TransportClientsFactory(
      _clientRegistry,
    );
    _filesfactory = TransportFilesFactory(
      _bindings,
      _callbacks,
      _outboundWorkerPointer,
      _outboundBufferFinalizers,
    );
    _inboundRing = _inboundWorkerPointer.ref.ring;
    _outboundRing = _outboundWorkerPointer.ref.ring;
    _inboundCqes = _bindings.transport_allocate_cqes(_transportPointer.ref.inbound_worker_configuration.ref.ring_size);
    _outboundCqes = _bindings.transport_allocate_cqes(_transportPointer.ref.outbound_worker_configuration.ref.ring_size);
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
      _callbacks,
    );
    _activator.close();
    _timeoutChecker = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (timer.isActive) {
        _bindings.transport_worker_check_event_timeouts(_inboundWorkerPointer);
        _bindings.transport_worker_check_event_timeouts(_outboundWorkerPointer);
      }
    });
  }

  void registerCallback(int id, Completer<int> completer) => _callbacks.setCustom(id, completer);

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

  void _handleInboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_inboundRingSize, _inboundCqes, _inboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _inboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_inboundRing, 1);
      final event = data & 0xffff;
      //print("${event.transportEventToString()} worker = ${_inboundWorkerPointer.ref.id}, result = $result,  bid = ${((data >> 16) & 0xffff)}");
      if (event & transportEventAll != 0) {
        _bindings.transport_worker_remove_event(_inboundWorkerPointer, data);
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
            _handleWrite((data >> 16) & 0xffff, fd, result);
            continue;
          case transportEventSendMessage:
            _handleSendMessage((data >> 16) & 0xffff, fd, result);
            continue;
          case transportEventAccept:
            _handleAccept(fd, result);
            continue;
        }
      }
    }
  }

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
      //print("${event.transportEventToString()} worker = ${_inboundWorkerPointer.ref.id}, result = $result,  bid = ${((data >> 16) & 0xffff)}");
      if (event & transportEventAll != 0) {
        _bindings.transport_worker_remove_event(_outboundWorkerPointer, data);
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

  @pragma(preferInlinePragma)
  bool _ensureServerIsActive(TransportServer server, int? bufferId) {
    server.onComplete();
    if (!server.active) {
      if (bufferId != null) _releaseInboundBuffer(bufferId);
      if (!server.hasPending()) _serverRegistry.removeServer(server.fd);
      return false;
    }
    return true;
  }

  @pragma(preferInlinePragma)
  bool _ensureClientIsActive(TransportClient client, int? bufferId, int fd) {
    client.onComplete();
    if (!client.active) {
      if (bufferId != null) _releaseOutboundBuffer(bufferId);
      if (!client.hasPending()) _clientRegistry.removeClient(fd);
      return false;
    }
    return true;
  }

  @pragma(preferInlinePragma)
  void _handleRead(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByClient(fd);
    if (server == null) return;
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == 0) {
      _releaseInboundBuffer(bufferId);
      _bindings.transport_close_descritor(fd);
      _serverRegistry.removeClient(fd);
      _callbacks.notifyInboundReadError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _inboundWorkerPointer.ref.buffers[bufferId].iov_len = result;
    _callbacks.notifyInboundRead(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleReceiveMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == 0) {
      _releaseInboundBuffer(bufferId);
      _callbacks.notifyInboundReadError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _inboundWorkerPointer.ref.buffers[bufferId].iov_len = result;
    _callbacks.notifyInboundRead(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleWrite(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByClient(fd);
    if (server == null) return;
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == 0) {
      _releaseInboundBuffer(bufferId);
      _bindings.transport_close_descritor(fd);
      _serverRegistry.removeClient(fd);
      _callbacks.notifyInboundWriteError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _releaseInboundBuffer(bufferId);
    _callbacks.notifyInboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleSendMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer());
      return;
    }
    if (result == 0) {
      _releaseInboundBuffer(bufferId);
      _callbacks.notifyInboundWriteError(bufferId, TransportTimeoutException.forServer());
      return;
    }
    _releaseInboundBuffer(bufferId);
    _callbacks.notifyInboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleReadReceiveMessageCallback(int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyOutboundReadError(bufferId, TransportClosedException.forClient());
      return;
    }
    if (result == 0) {
      _releaseOutboundBuffer(bufferId);
      _callbacks.notifyOutboundReadError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _outboundWorkerPointer.ref.buffers[bufferId].iov_len = result;
    _callbacks.notifyOutboundRead(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleWriteSendMessageCallback(int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, bufferId, fd)) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportClosedException.forClient());
      return;
    }
    if (result == 0) {
      _releaseOutboundBuffer(bufferId);
      _callbacks.notifyOutboundWriteError(bufferId, TransportTimeoutException.forClient());
      return;
    }
    _releaseOutboundBuffer(bufferId);
    _callbacks.notifyOutboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleConnect(int fd) {
    final client = _clientRegistry.get(fd);
    if (!_ensureClientIsActive(client, null, fd)) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient());
      return;
    }
    _callbacks.notifyConnect(fd, client);
  }

  @pragma(preferInlinePragma)
  void _handleAccept(int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!_ensureServerIsActive(server, null)) return;
    if (result == 0) return;
    _serverRegistry.addClient(fd, result);
    server.reaccept();
    _callbacks.notifyAccept(fd, TransportChannel(_inboundWorkerPointer, result, _bindings, _inboundBufferFinalizers));
  }

  @visibleForTesting
  void notifyCustom(int callback, int data) => _bindings.transport_worker_custom(_outboundWorkerPointer, callback, data);
}
