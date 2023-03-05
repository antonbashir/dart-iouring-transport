import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/acceptor.dart';
import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/worker.dart';

import 'bindings.dart';
import 'channels/channel.dart';
import 'lookup.dart';

class Transport {
  late String? libraryPath;
  late TransportBindings _bindings;
  late TransportLibrary _library;
  late Pointer<transport_t> _transport;

  final fromWorker = ReceivePort();

  Transport({String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    this.libraryPath = libraryPath;
  }

  TransportAcceptor acceptor(TransportAcceptorConfiguration configuration, String host, int port) => TransportAcceptor(
        _bindings,
      )..initialize(configuration, host, port);

  TransportChannel channel(TransportChannelConfiguration configuration) => TransportChannel(
        _bindings,
      )..initialize(configuration);

  void initialize(TransportConfiguration configuration, TransportAcceptor acceptor, TransportChannel channel) {
    using((Arena arena) {
      final transportConfiguration = arena<transport_configuration_t>();
      transportConfiguration.ref.log_level = configuration.logLevel;
      transportConfiguration.ref.log_colored = configuration.logColored;
      transportConfiguration.ref.acceptor_ring_size = acceptor.configuration.ringSize;
      transportConfiguration.ref.acceptor_ring_flags = acceptor.configuration.ringFlags;
      transportConfiguration.ref.channel_ring_size = channel.configuration.ringSize;
      transportConfiguration.ref.channel_ring_flags = channel.configuration.ringFlags;
      _transport = _bindings.transport_initialize(transportConfiguration, channel.channel, acceptor.acceptor);
    });
  }

  Future<void> work(int isolates, void Function(SendPort port) worker) async {
    Isolate.spawn<SendPort>(
      (port) async => await TransportWorker(port).accept(),
      fromWorker.sendPort,
      debugName: "acceptor",
    );

    for (var isolate = 0; isolate < isolates; isolate++) {
      Isolate.spawn<SendPort>(worker, fromWorker.sendPort, debugName: "worker-$isolate");
    }

    fromWorker.listen((port) {
      SendPort toWorker = port as SendPort;
      toWorker.send(libraryPath);
      toWorker.send(_transport.address);
    });
  }
}
