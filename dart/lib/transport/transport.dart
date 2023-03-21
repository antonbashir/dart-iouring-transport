import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/listener.dart';
import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/worker.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'lookup.dart';

class Transport {
  final TransportConfiguration transportConfiguration;
  final TransportAcceptorConfiguration acceptorConfiguration;
  final TransportChannelConfiguration channelConfiguration;
  final TransportConnectorConfiguration connectorConfiguration;
  late final TransportLogger logger;

  final _listenerExit = ReceivePort();
  final _workerExit = ReceivePort();

  late final String? _libraryPath;
  late final TransportBindings _bindings;
  late final TransportLibrary _library;
  late final Pointer<transport_t> _transport;

  Transport(this.transportConfiguration, this.acceptorConfiguration, this.channelConfiguration, this.connectorConfiguration, {String? libraryPath}) {
    this._libraryPath = libraryPath;

    _library = TransportLibrary.load(libraryPath: libraryPath);
    _bindings = TransportBindings(_library.library);

    logger = TransportLogger(transportConfiguration.logLevel);

    final nativeAcceptorConfiguration = calloc<transport_acceptor_configuration_t>();
    nativeAcceptorConfiguration.ref.max_connections = acceptorConfiguration.maxConnections;
    nativeAcceptorConfiguration.ref.receive_buffer_size = acceptorConfiguration.receiveBufferSize;
    nativeAcceptorConfiguration.ref.send_buffer_size = acceptorConfiguration.sendBufferSize;

    final nativeConnectorConfiguration = calloc<transport_connector_configuration_t>();
    nativeConnectorConfiguration.ref.max_connections = connectorConfiguration.maxConnections;
    nativeConnectorConfiguration.ref.receive_buffer_size = connectorConfiguration.receiveBufferSize;
    nativeConnectorConfiguration.ref.send_buffer_size = connectorConfiguration.sendBufferSize;

    final nativeChannelConfiguration = calloc<transport_listener_configuration_t>();
    nativeChannelConfiguration.ref.ring_flags = channelConfiguration.ringFlags;
    nativeChannelConfiguration.ref.ring_size = channelConfiguration.ringSize;
    nativeChannelConfiguration.ref.workers_count = transportConfiguration.workerInsolates;

    final nativeWorkerConfiguration = calloc<transport_worker_configuration_t>();
    nativeWorkerConfiguration.ref.ring_flags = channelConfiguration.ringFlags;
    nativeWorkerConfiguration.ref.ring_size = channelConfiguration.ringSize;
    nativeWorkerConfiguration.ref.buffer_size = channelConfiguration.bufferSize;
    nativeWorkerConfiguration.ref.buffers_count = channelConfiguration.buffersCount;

    _transport = _bindings.transport_initialize(
      nativeChannelConfiguration,
      nativeWorkerConfiguration,
      nativeConnectorConfiguration,
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
    final workersActivators = <SendPort>[];

    fromTransportToWorker.listen((ports) {
      logger.info("[worker]: initialized");
      SendPort toWorker = ports[0];
      workerMeessagePorts.add(ports[1]);
      workersActivators.add(ports[2]);
      int worker = _bindings.transport_worker_initialize(_transport.ref.worker_configuration, 1 << (64 - transportEventMax - workerMeessagePorts.length)).address;
      workers.add(worker);
      final workerConfiguration = [
        _libraryPath,
        _transport.address,
        worker,
        transportConfiguration.listenerIsolates,
        receiver,
      ];
      if (acceptor != null) workerConfiguration.add(acceptor.address);
      toWorker.send(workerConfiguration);
      if (workerMeessagePorts.length == transportConfiguration.workerInsolates) {
        workersCompleter.complete();
      }
    });

    fromTransportToListener.listen((port) async {
      await workersCompleter.future;
      logger.info("[listener]: initialized");
      final listenerPointer = _bindings.transport_listener_initialize(_transport.ref.listener_configuration);
      SendPort toListener = port as SendPort;
      toListener.send([_libraryPath, listenerPointer.address, channelConfiguration.ringSize, workerMeessagePorts, workers]);
      workersActivators.forEach((port) => port.send(listenerPointer.address));
      if (++listeners == transportConfiguration.listenerIsolates) {
        listenerCompleter.complete();
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
        (toTransport) => TransportListener(toTransport).listen(),
        fromTransportToListener.sendPort,
        onExit: _listenerExit.sendPort,
      );
    }

    await listenerCompleter.future;
    logger.info("[transport]: ready");
  }
}
