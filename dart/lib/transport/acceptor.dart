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
    final acceptor = using((Arena arena) => _bindings.transport_acceptor_initialize(_transport.ref.acceptor_configuration, host.toNativeUtf8(allocator: arena).cast(), port));
    _bindings.transport_prepare_accept(acceptor);
    waiter.send(null);
    await Future.delayed(Duration(milliseconds: 1));
    _bindings.transport_accept(_transport, acceptor);
    Isolate.exit();
  }
}
