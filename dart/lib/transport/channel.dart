import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';

import 'bindings.dart';
import 'exception.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportLoopConfiguration _configuration;
  final StreamController<Uint8List> _output = StreamController();
  final int _descriptor;
  bool _active = false;

  TransportChannel(this._bindings, this._configuration, this._ring, this._descriptor);

  void start() {
    _active = true;
    _receive();
  }

  void stop() {
    _active = false;
  }

  bool get active => _active;

  Stream<Uint8List> get output => _output.stream;

  void queueWrite(Uint8List bytes) {
    final Pointer<Uint8> buffer = calloc(sizeOf<Uint8>() * bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    _bindings.transport_queue_write(_ring, _descriptor, buffer.cast(), 0, bytes.length);
  }

  void queueRead(int size) {
    final Pointer<Uint8> buffer = calloc(sizeOf<Uint8>() * size);
    _bindings.transport_queue_read(_ring, _descriptor, buffer.cast(), 0, size);
  }

  Future<void> _receive() async {
    int initialEmptyCycles = _configuration.initialEmptyCycles;
    int maxEmptyCycles = _configuration.maxEmptyCycles;
    int cyclesMultiplier = _configuration.emptyCyclesMultiplier;
    int regularSleepSeconds = _configuration.regularSleepMillis;
    int maxSleepSeconds = _configuration.maxSleepMillis;
    int currentEmptyCycles = 0;
    int curentEmptyCyclesLimit = initialEmptyCycles;

    while (_active) {
      Pointer<Pointer<io_uring_cqe>> cqes = calloc(sizeOf<io_uring_cqe>() * _configuration.cqesSize);
      final received = _bindings.transport_submit_receive(_ring, cqes, _configuration.cqesSize, false);
      if (received < 0) {
        calloc.free(cqes);
        stop();
        throw new TransportException("Failed transport_submit_receive");
      }

      if (received == 0) {
        calloc.free(cqes);
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

        continue;
      }

      currentEmptyCycles = 0;
      curentEmptyCyclesLimit = initialEmptyCycles;
      for (var cqeIndex = 0; cqeIndex < received; cqeIndex++) {
        final Pointer<transport_message> message = Pointer.fromAddress(cqes[cqeIndex].ref.user_data);
        final Pointer<Uint8> bytes = message.ref.buffer.cast();
        _output.sink.add(bytes.asTypedList(message.ref.size));
        _bindings.transport_mark_cqe(_ring, cqes, cqeIndex);
      }
      calloc.free(cqes);
    }
    _bindings.transport_close_descriptor(_descriptor);
  }
}
