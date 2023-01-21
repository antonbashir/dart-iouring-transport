import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/channel.dart';
import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/connection.dart';

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

  TransportConnection connection(TransportLoopConfiguration configuration) => TransportConnection(_bindings, configuration, _ring);

  TransportChannel channel(TransportLoopConfiguration configuration, int descriptor) => TransportChannel(_bindings, configuration, _ring, descriptor);

  int file(String path) => using((Arena arena) => _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));

  int socket() => using((Arena arena) => _bindings.transport_socket_create());

  void closeDescriptor(int descriptor) => _bindings.transport_close_descriptor(descriptor);
}
