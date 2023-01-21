import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/channel.dart';
import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/connection.dart';

import 'bindings.dart';
import 'listener.dart';
import 'lookup.dart';

class Transport {
  final TransportConfiguration configuration;
  final TransportLoopConfiguration loopConfiguration;

  late TransportBindings _bindings;
  late TransportLibrary _library;
  late TransportListener _listener;
  late Pointer<io_uring> _ring;

  Transport(this.configuration, this.loopConfiguration, {String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
  }

  void initialize() => using((Arena arena) {
        final transportConfiguration = arena<transport_configuration_t>();
        transportConfiguration.ref.ring_size = configuration.ringSize;
        _ring = _bindings.transport_initialize(transportConfiguration);
        _listener = TransportListener(_bindings, _ring, loopConfiguration)..start();
      });

  void close() {
    _listener.stop();
    _bindings.transport_close();
  }

  TransportConnection connection() => TransportConnection(_bindings, _ring, _listener);

  TransportChannel channel(int descriptor) => TransportChannel(_bindings, _ring, descriptor, _listener);

  int file(String path) => using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));

  int socket() => using((Arena arena) => _bindings.transport_socket_create());

  void closeDescriptor(int descriptor) => _bindings.transport_close_descriptor(descriptor);
}
