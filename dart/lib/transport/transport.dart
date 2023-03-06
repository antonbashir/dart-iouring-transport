import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'lookup.dart';
import 'worker.dart';

class Transport {
  final fromChannel = ReceivePort();
  final fromAcceptor = ReceivePort();

  late String? libraryPath;
  late TransportBindings _bindings;
  late TransportLibrary _library;
  late Pointer<transport_t> _transport;

  Transport({String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    this.libraryPath = libraryPath;
  }

  void initialize(
    TransportConfiguration transportConfiguration,
    TransportAcceptorConfiguration acceptorConfiguration,
    TransportChannelConfiguration channelConfiguration,
  ) {
    final nativeTransportConfiguration = calloc<transport_configuration_t>();
    nativeTransportConfiguration.ref.log_level = transportConfiguration.logLevel;
    nativeTransportConfiguration.ref.log_colored = transportConfiguration.logColored;

    final nativeAcceptorConfiguration = calloc<transport_acceptor_configuration_t>();
    nativeAcceptorConfiguration.ref.backlog = acceptorConfiguration.backlog;
    nativeAcceptorConfiguration.ref.ring_flags = acceptorConfiguration.ringFlags;
    nativeAcceptorConfiguration.ref.ring_size = acceptorConfiguration.ringSize;

    final nativeChannelConfiguration = calloc<transport_channel_configuration_t>();
    nativeChannelConfiguration.ref.buffers_count = channelConfiguration.buffersCount;
    nativeChannelConfiguration.ref.buffer_size = channelConfiguration.bufferSize;
    nativeChannelConfiguration.ref.ring_flags = channelConfiguration.ringFlags;
    nativeChannelConfiguration.ref.ring_size = channelConfiguration.ringSize;

    _transport = _bindings.transport_initialize(
      nativeTransportConfiguration,
      nativeChannelConfiguration,
      nativeAcceptorConfiguration,
    );
  }

  Future<void> accept(String host, int port, void Function(SendPort port) worker, {int isolates = 1}) async {
    Isolate.spawn<SendPort>(
      (port) => TransportWorker(port).accept(),
      fromAcceptor.sendPort,
      debugName: "acceptor",
    );

    fromAcceptor.listen((acceptorPort) {
      SendPort toAcceptor = acceptorPort as SendPort;
      toAcceptor.send(libraryPath);
      toAcceptor.send(_transport.address);
      toAcceptor.send(host);
      toAcceptor.send(port);
    });

    for (var isolate = 0; isolate < isolates; isolate++) {
      Isolate.spawn<SendPort>(worker, fromChannel.sendPort, debugName: "worker-$isolate");
    }

    fromChannel.listen((port) {
      SendPort toChannel = port as SendPort;
      toChannel.send(libraryPath);
      toChannel.send(_transport.address);
    });
  }
}
