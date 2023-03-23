import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/exception.dart';
import 'package:iouring_transport/transport/listener.dart';
import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/worker.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'lookup.dart';

class Transport {
  final TransportConfiguration transportConfiguration;
  final TransportAcceptorConfiguration acceptorConfiguration;
  final TransportListenerConfiguration listenerConfiguration;
  final TransportWorkerConfiguration workerConfiguration;
  final TransportClientConfiguration clientConfiguration;
  late final TransportLogger logger;

  final _listenerExit = ReceivePort();
  final _workerExit = ReceivePort();

  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transport;

  Transport(this.transportConfiguration, this.acceptorConfiguration, this.listenerConfiguration, this.workerConfiguration, this.clientConfiguration, {String? libraryPath}) {
    this._libraryPath = libraryPath;

    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);

    logger = TransportLogger(transportConfiguration.logLevel);

    final nativeAcceptorConfiguration = calloc<transport_acceptor_configuration_t>();
    nativeAcceptorConfiguration.ref.max_connections = acceptorConfiguration.maxConnections;
    nativeAcceptorConfiguration.ref.receive_buffer_size = acceptorConfiguration.receiveBufferSize;
    nativeAcceptorConfiguration.ref.send_buffer_size = acceptorConfiguration.sendBufferSize;

    final nativeClientConfiguration = calloc<transport_client_configuration_t>();
    nativeClientConfiguration.ref.max_connections = clientConfiguration.maxConnections;
    nativeClientConfiguration.ref.receive_buffer_size = clientConfiguration.receiveBufferSize;
    nativeClientConfiguration.ref.send_buffer_size = clientConfiguration.sendBufferSize;

    final nativeListenerConfiguration = calloc<transport_listener_configuration_t>();
    nativeListenerConfiguration.ref.ring_flags = listenerConfiguration.ringFlags;
    nativeListenerConfiguration.ref.ring_size = listenerConfiguration.ringSize;
    nativeListenerConfiguration.ref.workers_count = transportConfiguration.workerInsolates;
    nativeListenerConfiguration.ref.buffers_count = workerConfiguration.buffersCount;

    final nativeWorkerConfiguration = calloc<transport_worker_configuration_t>();
    nativeWorkerConfiguration.ref.ring_flags = workerConfiguration.ringFlags;
    nativeWorkerConfiguration.ref.ring_size = workerConfiguration.ringSize;
    nativeWorkerConfiguration.ref.buffer_size = workerConfiguration.bufferSize;
    nativeWorkerConfiguration.ref.buffers_count = workerConfiguration.buffersCount;

    _transport = _bindings.transport_initialize(
      nativeListenerConfiguration,
      nativeWorkerConfiguration,
      nativeClientConfiguration,
      nativeAcceptorConfiguration,
    );
  }

  Future<void> shutdown() async {
    await _listenerExit.take(transportConfiguration.listenerIsolates).toList();
    _bindings.transport_destroy(_transport);
    logger.info("[transport]: destroyed");
  }

  Future<void> serve(String host, int port, void Function(SendPort input) worker, {SendPort? receiver}) => _run(
        worker,
        acceptor: using((Arena arena) => _bindings.transport_acceptor_initialize(
              _transport.ref.acceptor_configuration,
              host.toNativeUtf8(allocator: arena).cast(),
              port,
            )),
        receiver: receiver,
      );

  Future<void> run(void Function(SendPort input) worker, {Pointer<transport_acceptor>? acceptor, SendPort? receiver}) => _run(worker, receiver: receiver);

  Future<void> _run(void Function(SendPort input) worker, {Pointer<transport_acceptor>? acceptor, SendPort? receiver}) async {
    final fromTransportToListener = ReceivePort();
    final fromTransportToWorker = ReceivePort();
    var listeners = 0;
    final listenerCompleter = Completer();
    final workersCompleter = Completer();
    final workers = <int>[];
    final workerMeessagePorts = <SendPort>[];
    final workerActivators = <SendPort>[];

    fromTransportToWorker.listen((ports) {
      SendPort toWorker = ports[0];
      workerMeessagePorts.add(ports[1]);
      workerActivators.add(ports[2]);
      final workerPointer = _bindings.transport_worker_initialize(_transport.ref.worker_configuration, workers.length).address;
      if (workerPointer == nullptr) {
        logger.error("[worker] is null");
        listenerCompleter.completeError(TransportException("[worker] is null"));
        return;
      }
      workers.add(workerPointer);
      final workerConfiguration = [
        _libraryPath,
        _transport.address,
        workerPointer,
        receiver,
      ];
      if (acceptor != null) workerConfiguration.add(acceptor.address);
      toWorker.send(workerConfiguration);
      if (workers.length == transportConfiguration.workerInsolates) {
        workersCompleter.complete();
        logger.info("[workers]: initialized");
      }
    });

    fromTransportToListener.listen((port) async {
      await workersCompleter.future;
      final listenerPointer = _bindings.transport_listener_initialize(_transport.ref.listener_configuration);
      if (listenerPointer == nullptr) {
        logger.error("[listener] is null");
        listenerCompleter.completeError(TransportException("[listener] is null"));
        return;
      }
      logger.info("[listener]: created");
      for (var workerIndex = 0; workerIndex < listenerPointer.ref.workers_count; workerIndex++) {
        listenerPointer.ref.workers[workerIndex] = workers[workerIndex];
        _bindings.transport_listener_pool_add(Pointer.fromAddress(workers[workerIndex]).cast<transport_worker_t>().ref.listeners, listenerPointer);
      }
      logger.info("[listener]: added to pool");
      final listenerRegisterResult = _bindings.transport_listener_register_buffers(listenerPointer);
      if (listenerRegisterResult != 0) {
        logger.error("[listener] register buffers error code = $listenerRegisterResult, message = ${_bindings.strerror(-listenerRegisterResult).cast<Utf8>().toDartString()}");
        listenerCompleter.completeError(
            TransportException("[listener] register buffers error code = $listenerRegisterResult, message = ${_bindings.strerror(-listenerRegisterResult).cast<Utf8>().toDartString()}"));
        return;
      }
      logger.info("[listener]: buffers registered");
      (port as SendPort).send([
        _libraryPath,
        listenerPointer.address,
        listenerConfiguration.ringSize,
        workerMeessagePorts,
      ]);
      logger.info("[listener]: configuration sent");
      if (++listeners == transportConfiguration.listenerIsolates) {
        listenerCompleter.complete();
        logger.info("[listeners]: initialized");
      }
    });

    for (var isolate = 0; isolate < transportConfiguration.workerInsolates; isolate++) {
      Isolate.spawn<SendPort>(
        worker,
        fromTransportToWorker.sendPort,
        onExit: _workerExit.sendPort,
      );
    }

    for (var isolate = 0; isolate < transportConfiguration.listenerIsolates; isolate++) {
      Isolate.spawn<SendPort>(
        (toTransport) => TransportListener(toTransport).initialize(),
        fromTransportToListener.sendPort,
        onExit: _listenerExit.sendPort,
      );
    }

    await listenerCompleter.future;
    logger.info("[transport]: ready");
    workerActivators.forEach((port) => port.send(null));
  }
}
