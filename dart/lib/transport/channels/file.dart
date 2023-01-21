import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/listener.dart';

import '../bindings.dart';

class TransportFileChannel {
  final TransportBindings _bindings;
  final Pointer<io_uring> _ring;
  final TransportListener _listener;
  final StreamController<Uint8List> _output = StreamController();
  final int _descriptor;
  final _decoder = Utf8Decoder();
  final _encoder = Utf8Encoder();
  late StreamSubscription<Pointer<io_uring_cqe>> _subscription;
  bool _active = false;

  TransportFileChannel(this._bindings, this._ring, this._descriptor, this._listener);

  void start() {
    _active = true;
    _subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_message> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_READ && userData.ref.fd == _descriptor) {
        _output.add(userData.ref.buffer.cast<Uint8>().asTypedList(userData.ref.size));
        calloc.free(userData);
        calloc.free(cqe);
      }
    });
  }

  void stop() {
    _active = false;
    _subscription.cancel();
    _output.close();
    _bindings.transport_close_descriptor(_descriptor);
  }

  bool get active => _active;

  Stream<Uint8List> get bytesOutput => _output.stream;

  Stream<String> get stringOutput => _output.stream.map(_decoder.convert);

  Future<Uint8List> readBytes() async {
    final bytes = BytesBuilder();
    var offset = 0;
    queueRead();
    bytesOutput.listen((data) {
      if (data.isEmpty || data.first == -1 || data.first == 0) {
        stop();
        return;
      }
      bytes.add(data);
      queueRead(offset: offset += data.length);
    });
    await _output.done;
    return bytes.takeBytes();
  }

  Future<String> readString() => readBytes().then(_decoder.convert);

  void queueRead({int size = 64, int position = 0, int offset = 0}) {
    final Pointer<Uint8> buffer = calloc(sizeOf<Uint8>() * size);
    _bindings.transport_queue_read(_ring, _descriptor, buffer.cast(), position, size, offset);
  }

  void queueWriteBytes(Uint8List bytes, {int position = 0, int offset = 0}) {
    final Pointer<Uint8> buffer = calloc(sizeOf<Uint8>() * bytes.length);
    buffer.asTypedList(bytes.length).setAll(position, bytes);
    _bindings.transport_queue_write(_ring, _descriptor, buffer.cast(), position, bytes.length, offset);
  }

  void queueWriteString(String string, {int position = 0, int offset = 0}) => queueWriteBytes(_encoder.convert(string), position: position, offset: offset);
}
