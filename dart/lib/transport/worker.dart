import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'payload.dart';
import 'bindings.dart';
import 'buffers.dart';
import 'channel.dart';
import 'client/factory.dart';
import 'client/registry.dart';
import 'constants.dart';
import 'exception.dart';
import 'file/factory.dart';
import 'lookup.dart';
import 'error.dart';
import 'callbacks.dart';
import 'server/factory.dart';
import 'server/registry.dart';
import 'timeout.dart';

class TransportWorker {
  final _initializer = Completer();
  final _fromTransport = ReceivePort();
  final _jobs = <String, Queue<Completer<bool>>>{};

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
  late final RawReceivePort _jobRunner;
  late final TransportClientRegistry _clientRegistry;
  late final TransportServerRegistry _serverRegistry;
  late final TransportClientsFactory _clientsFactory;
  late final TransportServersFactory _serversFactory;
  late final TransportFilesFactory _filesFactory;
  late final TransportCallbacks _callbacks;
  late final int _inboundRingSize;
  late final int _outboundRingSize;
  late final TransportErrorHandler _errorHandler;
  late final TransportBuffers _inboundBuffers;
  late final TransportBuffers _outboundBuffers;
  late final TransportTimeoutChecker _inboundTimeoutChecker;
  late final TransportTimeoutChecker _outboundTimeoutChecker;
  late final SendPort _jobsListener;
  late final SendPort _jobCompletionsListener;
  late final TransportPayloadPool _inboundPayloadPool;
  late final TransportPayloadPool _outboundPayloadPool;

  late final SendPort? transmitter;

  int get id => _inboundWorkerPointer.ref.id;
  TransportServersFactory get servers => _serversFactory;
  TransportClientsFactory get clients => _clientsFactory;
  TransportFilesFactory get files => _filesFactory;

  TransportWorker(SendPort toTransport) {
    _jobRunner = RawReceivePort((input) {
      final queue = _jobs[input[0]];
      if (queue?.isNotEmpty == true) queue!.removeFirst().complete(input[1]);
    });
    _listener = RawReceivePort((_) {
      _handleInboundCqes();
      _handleOutboundCqes();
    });
    _activator = RawReceivePort((_) => _initializer.complete());
    _closer = RawReceivePort((_) async {
      _inboundTimeoutChecker.stop();
      _outboundTimeoutChecker.stop();
      await _clientRegistry.close();
      await _serverRegistry.close();
      _bindings.transport_worker_destroy(_outboundWorkerPointer);
      malloc.free(_outboundCqes);
      _bindings.transport_worker_destroy(_inboundWorkerPointer);
      malloc.free(_inboundCqes);
      _listener.close();
      _closer.close();
      _jobRunner.close();
      Isolate.exit();
    });
    toTransport.send([_fromTransport.sendPort, _listener.sendPort, _activator.sendPort, _closer.sendPort, _jobRunner.sendPort]);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first as List;
    final libraryPath = configuration[0] as String?;
    _transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    _inboundWorkerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_worker_t>();
    _outboundWorkerPointer = Pointer.fromAddress(configuration[3] as int).cast<transport_worker_t>();
    transmitter = configuration[4] as SendPort?;
    _jobsListener = configuration[5] as SendPort;
    _jobCompletionsListener = configuration[6] as SendPort;
    _fromTransport.close();
    await _initializer.future;
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _inboundBuffers = TransportBuffers(
      _bindings,
      _inboundWorkerPointer.ref.buffers,
      _inboundWorkerPointer,
    );
    _outboundBuffers = TransportBuffers(
      _bindings,
      _outboundWorkerPointer.ref.buffers,
      _outboundWorkerPointer,
    );
    _callbacks = TransportCallbacks(
      _inboundWorkerPointer.ref.buffers_count,
      _outboundWorkerPointer.ref.buffers_count,
    );
    _inboundPayloadPool = TransportPayloadPool(_inboundWorkerPointer.ref.buffers_count, _inboundBuffers);
    _outboundPayloadPool = TransportPayloadPool(_outboundWorkerPointer.ref.buffers_count, _outboundBuffers);
    _clientRegistry = TransportClientRegistry(
      _bindings,
      _callbacks,
      _outboundWorkerPointer,
      _outboundBuffers,
      _outboundPayloadPool,
    );
    _serverRegistry = TransportServerRegistry(
      _bindings,
      _callbacks,
      _inboundWorkerPointer,
      _inboundBuffers,
      _inboundPayloadPool,
    );
    _serversFactory = TransportServersFactory(
      _bindings,
      _serverRegistry,
      _inboundWorkerPointer,
      _inboundBuffers,
    );
    _clientsFactory = TransportClientsFactory(
      _clientRegistry,
    );
    _filesFactory = TransportFilesFactory(
      _bindings,
      _callbacks,
      _outboundWorkerPointer,
      _outboundBuffers,
      _outboundPayloadPool,
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
      _inboundBuffers,
      _outboundBuffers,
      _callbacks,
    );
    _inboundTimeoutChecker = TransportTimeoutChecker(
      _bindings,
      _inboundWorkerPointer,
      Duration(milliseconds: _inboundWorkerPointer.ref.timeout_checker_period_millis),
    );
    _outboundTimeoutChecker = TransportTimeoutChecker(
      _bindings,
      _outboundWorkerPointer,
      Duration(milliseconds: _outboundWorkerPointer.ref.timeout_checker_period_millis),
    );
    _inboundTimeoutChecker.start();
    _outboundTimeoutChecker.start();
    _activator.close();
  }

  void registerCallback(int id, Completer<int> completer) => _callbacks.setCustom(id, completer);

  void removeCallback(int id) => _callbacks.removeCustom(id);

  Future<void> job(FutureOr<void> Function() action, {String name = defaultJobName}) async {
    final completer = Completer<bool>();
    var current = _jobs[name];
    if (current == null) _jobs[name] = current = Queue();
    current.add(completer);
    _jobsListener.send([name, id]);
    if (await completer.future) {
      await action();
      _jobCompletionsListener.send(name);
    }
    _jobs.remove(name);
  }

  void _handleInboundCqes() {
    final cqeCount = _bindings.transport_worker_peek(_inboundRingSize, _inboundCqes, _inboundRing);
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = _inboundCqes[cqeIndex];
      final data = cqe.ref.user_data;
      final result = cqe.ref.res;
      _bindings.transport_cqe_advance(_inboundRing, 1);
      final event = data & 0xffff;
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
      final event = data & 0xffff;
      if (event & transportEventAll != 0) {
        _bindings.transport_worker_remove_event(_outboundWorkerPointer, data);
        if (event == transportEventCustom) {
          _callbacks.notifyCustom(result, data);
          continue;
        }
        final fd = (data >> 32) & 0xffffffff;
        if (result < 0) {
          _errorHandler.handle(result, data, fd, event);
          continue;
        }
        if (event == transportEventRead | transportEventClient || event == transportEventReceiveMessage | transportEventClient) {
          _handleReadReceiveClientCallback(event, (data >> 16) & 0xffff, result, fd);
          continue;
        }
        if (event == transportEventRead | transportEventFile || event == transportEventReceiveMessage | transportEventFile) {
          _handleReadReceiveFileCallback(event, (data >> 16) & 0xffff, result, fd);
          continue;
        }
        if (event == transportEventWrite | transportEventClient || event == transportEventSendMessage | transportEventClient) {
          _handleWriteSendClientCallback(event, (data >> 16) & 0xffff, result, fd);
          continue;
        }
        if (event == transportEventWrite | transportEventFile || event == transportEventSendMessage | transportEventFile) {
          _handleWriteSendFileCallback(event, (data >> 16) & 0xffff, result, fd);
          continue;
        }
        if (event == transportEventConnect) {
          _handleConnect(fd);
          continue;
        }
      }
    }
  }

  @pragma(preferInlinePragma)
  void _handleRead(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (!server.notifyConnection(fd, bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer(server.address, server.computeStreamAddress(fd)));
      return;
    }
    if (result == 0) {
      _inboundBuffers.release(bufferId);
      unawaited(server.closeConnection(fd));
      _callbacks.notifyInboundReadError(
        bufferId,
        TransportZeroDataException(
          event: TransportEvent.serverRead,
          source: server.address,
          target: server.computeStreamAddress(fd),
        ),
      );
      return;
    }
    _callbacks.notifyInboundRead(bufferId, result);
  }

  @pragma(preferInlinePragma)
  void _handleWrite(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByConnection(fd);
    if (!server.notifyConnection(fd, bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer(server.address, server.computeStreamAddress(fd)));
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == 0) {
      unawaited(server.closeConnection(fd));
      _callbacks.notifyInboundWriteError(
        bufferId,
        TransportZeroDataException(
          event: TransportEvent.serverWrite,
          source: server.address,
          target: server.computeStreamAddress(fd),
        ),
      );
      return;
    }
    _callbacks.notifyInboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleReceiveMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundReadError(bufferId, TransportClosedException.forServer(server.address, server.computeDatagramAddress(bufferId)));
      return;
    }
    if (result == 0) {
      _inboundBuffers.release(bufferId);
      _callbacks.notifyInboundReadError(
        bufferId,
        TransportZeroDataException(
          event: TransportEvent.serverReceive,
          source: server.address,
          target: server.computeDatagramAddress(bufferId),
        ),
      );
      return;
    }
    _callbacks.notifyInboundRead(bufferId, result);
  }

  @pragma(preferInlinePragma)
  void _handleSendMessage(int bufferId, int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyData(bufferId)) {
      _callbacks.notifyInboundWriteError(bufferId, TransportClosedException.forServer(server.address, server.computeDatagramAddress(bufferId)));
      return;
    }
    _inboundBuffers.release(bufferId);
    if (result == 0) {
      _callbacks.notifyInboundWriteError(
        bufferId,
        TransportZeroDataException(
          event: TransportEvent.serverSend,
          source: server.address,
          target: server.computeDatagramAddress(bufferId),
        ),
      );
      return;
    }
    _callbacks.notifyInboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleReadReceiveClientCallback(int event, int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundReadError(bufferId, TransportClosedException.forClient(client.source, client.destination));
      return;
    }
    if (result == 0) {
      _outboundBuffers.release(bufferId);
      _callbacks.notifyOutboundReadError(
          bufferId,
          TransportZeroDataException(
            event: TransportEvent.ofEvent(event),
            source: client.source,
            target: client.destination,
          ));
      return;
    }
    _callbacks.notifyOutboundRead(bufferId, result);
  }

  @pragma(preferInlinePragma)
  void _handleReadReceiveFileCallback(int event, int bufferId, int result, int fd) {
    _callbacks.notifyOutboundRead(bufferId, result);
  }

  @pragma(preferInlinePragma)
  void _handleWriteSendClientCallback(int event, int bufferId, int result, int fd) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyData(bufferId)) {
      _callbacks.notifyOutboundWriteError(bufferId, TransportClosedException.forClient(client.source, client.destination));
      return;
    }
    _outboundBuffers.release(bufferId);
    if (result == 0) {
      _callbacks.notifyOutboundWriteError(
          bufferId,
          TransportZeroDataException(
            event: TransportEvent.ofEvent(event),
            source: client.source,
            target: client.destination,
          ));
      return;
    }
    _callbacks.notifyOutboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleWriteSendFileCallback(int event, int bufferId, int result, int fd) {
    _outboundBuffers.release(bufferId);
    _callbacks.notifyOutboundWrite(bufferId);
  }

  @pragma(preferInlinePragma)
  void _handleConnect(int fd) {
    final client = _clientRegistry.get(fd);
    if (!client.notifyConnect()) {
      _callbacks.notifyConnectError(fd, TransportClosedException.forClient(client.source, client.destination));
      return;
    }
    _callbacks.notifyConnect(fd, client);
  }

  @pragma(preferInlinePragma)
  void _handleAccept(int fd, int result) {
    final server = _serverRegistry.getByServer(fd);
    if (!server.notifyAccept()) return;
    _serverRegistry.addConnection(fd, result);
    server.reaccept();
    _callbacks.notifyAccept(fd, TransportChannel(_inboundWorkerPointer, result, _bindings, _inboundBuffers));
  }

  @visibleForTesting
  void notifyCustom(int id, int data) {
    _bindings.transport_worker_custom(_outboundWorkerPointer, id, data);
  }
}
