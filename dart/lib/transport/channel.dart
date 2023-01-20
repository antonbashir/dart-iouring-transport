import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';

import 'bindings.dart';
import 'exception.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportChannelConfiguration _configuration;
  final StreamController<Uint8List> _output = StreamController();
  final utf8Encoder = Utf8Encoder();
  final utf8Decoder = Utf8Decoder();
  bool active = false;

  TransportChannel(this._bindings, this._configuration, this._ring);

  void start() {
    active = true;
    _receive();
  }

  void stop() {
    active = false;
  }

  void writeBytes(int descriptor, Uint8List bytes) {
    final Pointer<Uint8> buffer = calloc(sizeOf<Uint8>() * bytes.length);
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    _bindings.transport_queue_write(_ring, descriptor, buffer.cast(), 0, bytes.length);
  }

  void writeString(int descriptor, String string) => writeBytes(descriptor, utf8Encoder.convert(string));

  Stream<Uint8List> get outputBytes => _output.stream;

  Stream<String> get outputString => _output.stream.map(utf8Decoder.convert);

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
  }
}
