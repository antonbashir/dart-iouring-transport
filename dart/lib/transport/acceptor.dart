import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'configuration.dart';
import 'exception.dart';

class TransportAcceptor {
  final TransportLoopConfiguration _configuration;
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;

  TransportAcceptor(this._bindings, this._configuration, this._ring);

  Future<int> accept() async {
    int currentEmptyCycles = 0;
    int curentEmptyCyclesLimit = _configuration.initialEmptyCycles;

    while (true) {
      Pointer<Pointer<io_uring_cqe>> cqes = calloc(sizeOf<io_uring_cqe>());
      final received = _bindings.transport_submit_receive(_ring, cqes, 1, false);
      if (received < 0) {
        calloc.free(cqes);
        throw new TransportException("Failed transport_submit_receive");
      }

      if (received == 0) {
        calloc.free(cqes);
        currentEmptyCycles++;
        if (currentEmptyCycles >= _configuration.maxEmptyCycles) {
          await Future.delayed(Duration(milliseconds: _configuration.maxSleepMillis));
          continue;
        }

        if (currentEmptyCycles >= curentEmptyCyclesLimit) {
          curentEmptyCyclesLimit *= _configuration.emptyCyclesMultiplier;
          await Future.delayed(Duration(milliseconds: _configuration.regularSleepMillis));
          continue;
        }

        continue;
      }

      currentEmptyCycles = 0;
      curentEmptyCyclesLimit = _configuration.initialEmptyCycles;
      for (var cqeIndex = 0; cqeIndex < received; cqeIndex++) {
        _bindings.transport_mark_cqe(_ring, cqes, cqeIndex);
        return cqes[cqeIndex].ref.res;
      }

      calloc.free(cqes);
    }
  }
}
