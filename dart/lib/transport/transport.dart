import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/connector.dart';
import 'package:iouring_transport/transport/acceptor.dart';

import 'bindings.dart';
import 'channels/file.dart';
import 'channels/channel.dart';
import 'lookup.dart';
import 'payload.dart';

class Transport {
  final TransportConfiguration configuration;
  final TransportControllerConfiguration controllerConfiguration;

  late TransportBindings _bindings;
  late TransportLibrary _library;
  late Pointer<transport_controller_t> _controller;
  late Pointer<transport_t> _transport;

  Transport(this.configuration, this.controllerConfiguration, {String? libraryPath}) {
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
      transportConfiguration.ref.log_level = configuration.logLevel;
      transportConfiguration.ref.log_colored = configuration.logColored;
      transportConfiguration.ref.slab_size = configuration.slabSize;
      transportConfiguration.ref.memory_quota = configuration.memoryQuota;
      transportConfiguration.ref.slab_allocation_granularity = configuration.slabAllocationGranularity;
      transportConfiguration.ref.slab_allocation_factor = configuration.slabAllocationFactor;
      transportConfiguration.ref.slab_allocation_minimal_object_size = configuration.slabAllocationMinimalObjectSize;
      _transport = _bindings.transport_initialize(transportConfiguration);
      final controllerConfiguration = arena<transport_controller_configuration_t>();
      controllerConfiguration.ref.ring_retry_max_count = this.controllerConfiguration.retryMaxCount;
      controllerConfiguration.ref.internal_ring_size = this.controllerConfiguration.internalRingSize;
      controllerConfiguration.ref.balancer_configuration = arena<transport_balancer_configuration>();
      controllerConfiguration.ref.balancer_configuration.ref.type = transport_balancer_type.TRANSPORT_BALANCER_ROUND_ROBBIN;
      _controller = _bindings.transport_controller_start(_transport, controllerConfiguration);
    });
  }

  void close() {
    _bindings.transport_controller_stop(_controller);
    _bindings.transport_close(_transport);
  }

  TransportConnector connector(TransportConnectorConfiguration configuration) => TransportConnector(
        configuration,
        _bindings,
        _transport,
        _controller,
      );

  TransportAcceptor acceptor(TransportAcceptorConfiguration configuration) => TransportAcceptor(
        configuration,
        _bindings,
        _transport,
        _controller,
      );

  TransportChannel channel(
    TransportChannelConfiguration configuration, {
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    return TransportChannel(
      _bindings,
      configuration,
      _transport,
      _controller,
    )..start(
        onRead: onRead,
        onWrite: onWrite,
        onStop: onStop,
      );
  }

  List<TransportChannel> channels(
    TransportChannelConfiguration configuration, {
    int count = 1,
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    List<TransportChannel> channels = [];
    for (var index = 0; index < count; index++) {
      channels.add(channel(configuration, onRead: onRead, onWrite: onWrite, onStop: onStop));
    }
    return channels;
  }

  TransportFileChannel file(
    String path,
    TransportChannelConfiguration configuration, {
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    return TransportFileChannel(
      _bindings,
      _transport,
      _controller,
      configuration,
      onStop: onStop,
    )..start();
  }
}
