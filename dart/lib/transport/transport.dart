import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'lookup.dart';

class Transport {
  late TransportBindings _bindings;
  late TransportLibrary _library;

  Transport({String? libraryPath}) {
    _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
  }

  void initialize() => using((Arena arena) {
        print(_bindings.transport_initialize(arena<transport_configuration_t>()..ref.ring_size = 120));
      });

  void queueRead() {
    Uint8List frame = Uint8List.fromList([1, 2, 3]);
    final frameData = calloc<Uint8>(sizeOf<Uint8>() * frame.length);
    frameData.asTypedList(frame.length).setAll(0, frame);
    final fd = _bindings.transport_socket_create();
    _bindings.transport_queue_read(fd, frameData.cast(), 0, frame.length);
    Pointer<Pointer<io_uring_cqe>> cqes = calloc(sizeOf<io_uring_cqe>() * 2);
    cqes[0] = calloc<io_uring_cqe>();
    cqes[1] = calloc<io_uring_cqe>();
    _bindings.transport_submit_receive(cqes, 2, false);
    print(cqes[0]);
    print(cqes[1]);
  }
}
