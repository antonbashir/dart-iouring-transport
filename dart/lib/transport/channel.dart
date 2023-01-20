import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';

import 'bindings.dart';
import 'exception.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final TransportChannelConfiguration _configuration;
  bool active = false;

  TransportChannel(this._bindings, this._configuration);

  void start() {
    active = true;
    _receive();
  }

  void stop() {
    active = false;
  }

  void accept() {}

  void connect() {}

  void write() {}

  Future<void> _receive() async {
    int initialEmptyCycles = _configuration.initialEmptyCycles;
    int maxEmptyCycles = _configuration.maxEmptyCycles;
    int cyclesMultiplier = _configuration.emptyCyclesMultiplier;
    int regularSleepSeconds = _configuration.regularSleepMillis;
    int maxSleepSeconds = _configuration.maxSleepMillis;
    int currentEmptyCycles = 0;
    int curentEmptyCyclesLimit = initialEmptyCycles;

    while (active) {
      Pointer<Pointer<io_uring_cqe>> cqes = calloc(sizeOf<io_uring_cqe>() * 128);
      final received = _bindings.transport_submit_receive(cqes, 128, false);
      if (received < 0) {
        stop();
        throw new TransportException("Failed transport_submit_receive");
      }

      if (received == 0) {
        currentEmptyCycles++;
        if (currentEmptyCycles >= maxEmptyCycles) {
          await Future.delayed(Duration(milliseconds: maxSleepSeconds));
          continue;
        }

        if (currentEmptyCycles >= curentEmptyCyclesLimit) {
          curentEmptyCyclesLimit *= cyclesMultiplier;
          await Future.delayed(Duration(milliseconds: regularSleepSeconds));
          continue;
        }
      }

      currentEmptyCycles = 0;
      curentEmptyCyclesLimit = initialEmptyCycles;

      for (var cqeIndex = 0; cqeIndex < received; cqeIndex++) {
        final Pointer<transport_message> message = Pointer.fromAddress(cqes[cqeIndex].ref.user_data);
        final Pointer<Uint8> bytes = message.ref.buffer.cast();
        print("Bytes: ${bytes.asTypedList(1024).length}");
        _bindings.transport_mark_cqe(cqes, cqeIndex);
      }
    }
  }
}
