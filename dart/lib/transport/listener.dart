import 'dart:async';
import 'dart:ffi';

import 'bindings.dart';

class TransportPoller {
  final TransportBindings _bindings;
  final Pointer<transport_listener_t> _listener;

  TransportPoller(this._bindings, this._listener);

  bool active = false;

  Future<void> start() async {
    // active = true;
    // while (active) {
    //   _bindings.transport_listener_poll(_listener, false);
    //   await Future.delayed(Duration.zero);
    // }
  }

  void stop() {
    active = false;
  }
}
