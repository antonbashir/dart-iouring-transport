import 'dart:ffi';
import 'dart:isolate';

import 'bindings.dart';
import 'lookup.dart';

class TransportEvent {
  late int result;
  final void Function(TransportEvent event) callback;

  TransportEvent(this.callback);
}

class TransportEventLoop {
  final fromServer = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_event_loop_t> _pointer;

  TransportEventLoop(SendPort toServer) {
    toServer.send(fromServer.sendPort);
  }

  Future<void> start() async {
    final configuration = await fromServer.take(2).toList();
    final libraryPath = configuration[0] as String?;
    _pointer = Pointer.fromAddress(configuration[1] as int);
    fromServer.close();
    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    RawReceivePort port = RawReceivePort(_callback);
    _bindings.transport_event_loop_start(_pointer, port.sendPort.nativePort);
    port.close();
    Isolate.exit();
  }

  void stop() => _bindings.transport_event_loop_stop(_pointer);

  void _callback(dynamic event) {
    TransportEvent transportEvent = _bindings.Dart_HandleFromPersistent(event) as TransportEvent;
    _bindings.Dart_DeletePersistentHandle(event);
    transportEvent.callback(transportEvent);
  }
}
