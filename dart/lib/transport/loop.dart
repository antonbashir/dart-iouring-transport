import 'dart:ffi';
import 'dart:isolate';

import 'bindings.dart';
import 'lookup.dart';

class TransportEventLoop {
  final fromServer = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_event_loop_t> _pointer;

  TransportEventLoop(SendPort toServer) {
    toServer.send(fromServer.sendPort);
  }

  Future<void> start() async {
    final configuration = await fromServer.take(3).toList();
    final libraryPath = configuration[0] as String?;
    _pointer = Pointer.fromAddress(configuration[1] as int);
    final callbackPort = configuration[2] as int;
    fromServer.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _bindings.transport_event_loop_start(_pointer, callbackPort);
    Isolate.exit();
  }

  void stop() => _bindings.transport_event_loop_stop(_pointer);
}
