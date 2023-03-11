import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';

class TransportEvent {
  late int result;
  final void Function(TransportEvent event) callback;

  TransportEvent(this.callback);
}

class TransportEventLoop {
  final TransportBindings _bindings;
  final TransportEventLoopConfiguration _configuration;
  late final RawReceivePort port;

  late final Pointer<transport_event_loop_t> _loop;

  TransportEventLoop(this._configuration, this._bindings) {
    port = RawReceivePort(_callback);
  }

  void stop() {
    _bindings.transport_event_loop_stop(_loop);
  }

  void start() {
    using((Arena arena) {
      final nativeConfiguration = arena<transport_event_loop_configuration>();
      nativeConfiguration.ref.ring_flags = _configuration.ringFlags;
      nativeConfiguration.ref.ring_size = _configuration.ringSize;
      _loop = _bindings.transport_event_loop_initialize(nativeConfiguration, port.sendPort.nativePort);
    });
    _bindings.transport_event_loop_start(_loop);
    port.close();
    Isolate.exit();
  }

  void _callback(dynamic event) {
    (event as TransportEvent).callback(event);
  }
}
