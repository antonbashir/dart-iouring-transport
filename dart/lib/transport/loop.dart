import 'dart:ffi';
import 'dart:isolate';

import 'bindings.dart';

class TransportEvent {
  late int result;
  final void Function(TransportEvent event) callback;

  TransportEvent(this.callback);
}

class TransportEventLoop {
  final TransportBindings _bindings;
  late final RawReceivePort port;

  late final Pointer<transport_event_loop_t> _loop;

  TransportEventLoop(this._bindings) {
    port = RawReceivePort(_callback);
  }

  void stop() {
    _bindings.transport_event_loop_stop(_loop);
  }

  void start() {
    _bindings.transport_event_loop_start(_loop);
    port.close();
    Isolate.exit();
  }

  void _callback(dynamic event) {
    (event as TransportEvent).callback(event);
  }
}
