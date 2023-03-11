import 'dart:ffi';

import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';

import 'bindings.dart';

class TransportProvider {
  final Pointer<transport_event_loop_t> _loop;
  final TransportBindings _bindings;
  late final TransportClient client;
  late final TransportFile file;

  TransportProvider(this._loop, this._bindings) {
    client = TransportClient(_loop, _bindings);
    file = TransportFile(_loop, _bindings);
  }
}
