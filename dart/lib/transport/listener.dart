import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'exception.dart';

class TransportListener {
  final TransportBindings _bindings;
  final Pointer<transport_context_t> _context;
  final TransportLoopConfiguration _configuration;
  final StreamController<Pointer<io_uring_cqe>> _cqes = StreamController();
  late Stream<Pointer<io_uring_cqe>> _cqesBroadcast = _cqes.stream.asBroadcastStream();
  bool _active = false;

  TransportListener(this._bindings, this._context, this._configuration);

  void start() {
    _active = true;
    _listen();
  }

  void stop() {
    _active = false;
  }

  Stream<Pointer<io_uring_cqe>> get cqes => _cqesBroadcast;

  Future<void> _listen() async {
    int initialEmptyCycles = _configuration.initialEmptyCycles;
    int maxEmptyCycles = _configuration.maxEmptyCycles;
    int cyclesMultiplier = _configuration.emptyCyclesMultiplier;
    int regularSleepMillis = _configuration.regularSleepMillis;
    int maxSleepMillis = _configuration.maxSleepMillis;
    int currentEmptyCycles = 0;
    int curentEmptyCyclesLimit = initialEmptyCycles;

    while (_active) {
      Pointer<Pointer<io_uring_cqe>> cqes = _bindings.transport_free_cqes(context, cqes, count) calloc(sizeOf<io_uring_cqe>() * _configuration.cqesSize);
      final received = _bindings.transport_submit_receive(_context, cqes, _configuration.cqesSize, false);
      if (received < 0) {
        calloc.free(cqes);
        stop();
        throw new TransportException("Failed transport_submit_receive");
      }

      if (received == 0) {
        calloc.free(cqes);
        currentEmptyCycles++;
        if (currentEmptyCycles >= maxEmptyCycles) {
          await Future.delayed(Duration(milliseconds: maxSleepMillis));
          continue;
        }

        if (currentEmptyCycles >= curentEmptyCyclesLimit) {
          curentEmptyCyclesLimit *= cyclesMultiplier;
          await Future.delayed(Duration(milliseconds: regularSleepMillis));
          continue;
        }

        continue;
      }

      currentEmptyCycles = 0;
      curentEmptyCyclesLimit = initialEmptyCycles;
      for (var cqeIndex = 0; cqeIndex < received; cqeIndex++) {
        final cqe = cqes[cqeIndex];
        final userData = Pointer<transport_message>.fromAddress(cqe.ref.user_data);
        final Pointer<io_uring_cqe> cqeCopy = _bindings.transport_allocate_object(_context, sizeOf<io_uring_cqe>()).cast();
        final Pointer<transport_message> userDataCopy = _bindings.transport_allocate_object(_context, sizeOf<transport_message>()).cast();
        cqeCopy.ref = cqe.ref;
        userDataCopy.ref = userData.ref;
        cqeCopy.ref.user_data = userDataCopy.address;
        _cqes.sink.add(cqeCopy);
        _bindings.transport_mark_cqe(_context, userData.ref.type, cqe);
      }
      calloc.free(cqes);
    }
  }
}
