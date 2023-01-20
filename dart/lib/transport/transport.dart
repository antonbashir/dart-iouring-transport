import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/channel.dart';
import 'package:iouring_transport/transport/configuration.dart';

import 'bindings.dart';
import 'lookup.dart';

class Transport {
  late TransportBindings _bindings;
  late TransportLibrary _library;

  late Pointer<io_uring> _ring;

  Transport({String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
  }

  void initialize(TransportConfiguration configuration) => using((Arena arena) {
        final transportConfiguration = arena<transport_configuration_t>();
        transportConfiguration.ref.ring_size = configuration.ringSize;
        _ring = _bindings.transport_initialize(transportConfiguration);
      });

  void close() => _bindings.transport_close();

  TransportChannel channel(TransportChannelConfiguration configuration) => TransportChannel(_bindings, configuration, _ring);
}
