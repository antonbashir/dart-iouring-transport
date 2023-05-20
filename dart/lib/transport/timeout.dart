import 'dart:async';
import 'dart:ffi';

import 'bindings.dart';

class TransportTimeoutChecker {
  final TransportBindings _bindings;
  final Pointer<transport_worker_t> _workerPointer;
  final Duration _period;

  late final Timer _timer;

  TransportTimeoutChecker(this._bindings, this._workerPointer, this._period);

  void start() => _timer = Timer.periodic(_period, _check);

  void stop() => _timer.cancel();

  void _check(Timer timer) {
    if (timer.isActive) _bindings.transport_worker_check_event_timeouts(_workerPointer);
  }
}
