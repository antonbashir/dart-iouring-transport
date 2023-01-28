import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/connection.dart';

import 'bindings.dart';
import 'channels/file.dart';
import 'channels/channel.dart';
import 'lookup.dart';
import 'payload.dart';

class Transport {
  final TransportConfiguration configuration;
  final TransportListenerConfiguration listenerConfiguration;

  late TransportBindings _bindings;
  late TransportLibrary _library;
  late Pointer<transport_listener_t> _listener;
  late Pointer<transport_t> _transport;

  Transport(this.configuration, this.listenerConfiguration, {String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
  }

  Future<void> initialize() async {
    using((Arena arena) {
      final transportConfiguration = arena<transport_configuration_t>();
      transportConfiguration.ref.ring_size = configuration.ringSize;
      transportConfiguration.ref.slab_size = configuration.slabSize;
      transportConfiguration.ref.memory_quota = configuration.memoryQuota;
      transportConfiguration.ref.slab_allocation_granularity = configuration.slabAllocationGranularity;
      transportConfiguration.ref.slab_allocation_factor = configuration.slabAllocationFactor;
      transportConfiguration.ref.slab_allocation_minimal_object_size = configuration.slabAllocationMinimalObjectSize;
      _transport = _bindings.transport_initialize(transportConfiguration);
      final listenerConfiguration = arena<transport_listener_configuration_t>();
      listenerConfiguration.ref.cqe_size = this.listenerConfiguration.cqesSize;
      _listener = _bindings.transport_listener_start(_transport, listenerConfiguration);
    });
    while (true) {
      _bindings.transport_listener_poll(_listener, false);
      await Future.delayed(Duration.zero);
    }
  }

  void close() {
    _bindings.transport_listener_stop(_listener);
    _bindings.transport_close(_transport);
  }

  TransportConnection connection(TransportConnectionConfiguration connectionConfiguration, TransportChannelConfiguration channelConfiguration) => TransportConnection(
        connectionConfiguration,
        channelConfiguration,
        _bindings,
        _transport,
        _listener,
      )..initialize();

  TransportChannel channel(
    int descriptor,
    TransportChannelConfiguration configuration, {
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    return TransportChannel(
      _bindings,
      configuration,
      _transport,
      _listener,
      descriptor,
    )..start(
        onRead: onRead,
        onWrite: onWrite,
        onStop: onStop,
      );
  }

  TransportFileChannel file(
    String path,
    TransportChannelConfiguration configuration, {
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    final descriptor = using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
    return TransportFileChannel(
      _bindings,
      _transport,
      _listener,
      configuration,
      descriptor,
      onStop: onStop,
    )..start();
  }
}
