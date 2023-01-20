import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';

import 'bindings.dart';
import 'exception.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportChannelConfiguration _configuration;
  bool active = false;

  TransportChannel(this._bindings, this._configuration, this._ring);

  void start() {
    active = true;
    _receive();
  }

  void stop() {
    active = false;
  }

  void writeToFile(String path, String text) {
    final descriptor = _bindings.transport_file_open(path.toNativeUtf8().cast());
    final bytes = Utf8Encoder().convert(text);
    final Pointer<Uint8> buffer = calloc(sizeOf<Uint8>() * 1024);
    buffer.asTypedList(1024).setAll(0, bytes);
    _bindings.transport_queue_write(_ring, descriptor, buffer.cast(), 0, 1024);
  }

  Future<void> _receive() async {
    int initialEmptyCycles = _configuration.initialEmptyCycles;
    int maxEmptyCycles = _configuration.maxEmptyCycles;
    int cyclesMultiplier = _configuration.emptyCyclesMultiplier;
    int regularSleepSeconds = _configuration.regularSleepMillis;
    int maxSleepSeconds = _configuration.maxSleepMillis;
    int currentEmptyCycles = 0;
    int curentEmptyCyclesLimit = initialEmptyCycles;

    while (active) {
      Pointer<Pointer<io_uring_cqe>> cqes = calloc(sizeOf<io_uring_cqe>() * _configuration.cqesSize);
      final received = _bindings.transport_submit_receive(_ring, cqes, _configuration.cqesSize, false);
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
        _bindings.transport_mark_cqe(_ring, cqes, cqeIndex);
      }
      calloc.free(cqes);
    }
  }
}
