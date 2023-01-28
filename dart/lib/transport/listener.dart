import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportListener {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final TransportListenerConfiguration _configuration;

  late Pointer<transport_listener_t> _listener;

  TransportListener(this._bindings, this._transport, this._configuration);

  void start() {
    using((Arena arena) {
      final configuration = arena<transport_listener_configuration>();
      configuration.ref.cqe_size = _configuration.cqesSize;
      _listener = _bindings.transport_listener_start(_transport, configuration);
    });
  }

  void stop() {
    _bindings.transport_listener_stop(_listener);
  }
}
