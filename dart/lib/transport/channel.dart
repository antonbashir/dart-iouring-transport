import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/listener.dart';

import 'bindings.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportListener _listener;
  final StreamController<Uint8List> _output = StreamController();
  final int _descriptor;
  bool _active = false;

  TransportChannel(this._bindings, this._ring, this._descriptor, this._listener);

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
    _listener.cqes.listen((cqe) {
      Pointer<transport_message> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_READ) {
        _output.add(userData.ref.buffer.cast<Uint8>().asTypedList(userData.ref.size));
        calloc.free(userData);
        calloc.free(cqe);
      }
    });
  }
}
