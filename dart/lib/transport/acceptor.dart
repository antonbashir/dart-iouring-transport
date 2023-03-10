import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'lookup.dart';

class TransportAcceptor {
  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;

  TransportAcceptor(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> accept() async {
    final configuration = await fromTransport.take(4).toList();
    final libraryPath = configuration[0] as String?;
    _transport = Pointer.fromAddress(configuration[1] as int);
    String host = configuration[2] as String;
    int port = configuration[3] as int;
    fromTransport.close();
    final _library = libraryPath != null
        ? File(libraryPath).existsSync()
            ? TransportLibrary(DynamicLibrary.open(libraryPath), libraryPath)
            : loadBindingLibrary()
        : loadBindingLibrary();
    _bindings = TransportBindings(_library.library);
    using((Arena arena) {
      _bindings.transport_accept(_transport, host.toNativeUtf8(allocator: arena).cast(), port);
    });
    Isolate.exit();
  }
}
