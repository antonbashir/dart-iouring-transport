import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'lookup.dart';

class TransportAcceptor {
  final _fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;

  TransportAcceptor(SendPort toTransport) {
    toTransport.send(_fromTransport.sendPort);
  }

  Future<void> accept() async {
    final configuration = await _fromTransport.first;
    final libraryPath = configuration[0] as String?;
    _transport = Pointer.fromAddress(configuration[1] as int);
    String host = configuration[2] as String;
    int port = configuration[3] as int;
    SendPort waiter = configuration[4] as SendPort;
    _fromTransport.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    waiter.send(null);
    using((Arena arena) => _bindings.transport_accept(_transport, host.toNativeUtf8(allocator: arena).cast(), port));
    Isolate.exit();
  }
}
