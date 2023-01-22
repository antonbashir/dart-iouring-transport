import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/listener.dart';

import '../bindings.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<transport_context_t> _context;
  final TransportListener _listener;
  final StreamController<Uint8List> _output = StreamController();
  final StreamController<Uint8List> _input = StreamController();
  final int _descriptor;
  final _decoder = Utf8Decoder();
  final _encoder = Utf8Encoder();
  late StreamSubscription<Pointer<io_uring_cqe>> _subscription;
  bool _active = false;

  TransportChannel(this._bindings, this._context, this._descriptor, this._listener);

  void start() {
    _active = true;
    _subscription = _listener.cqes.listen((cqe) {
      Pointer<transport_message> userData = Pointer.fromAddress(cqe.ref.user_data);
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_READ && userData.ref.fd == _descriptor) {
        _output.add(userData.ref.read_buffer.ref.rpos.cast<Uint8>().asTypedList(userData.ref.size));
        _bindings.transport_complete_read(_context, userData);
        calloc.free(userData);
        calloc.free(cqe);
      }
      if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_WRITE && userData.ref.fd == _descriptor) {
        final writeBuffer = _bindings.transport_copy_write_buffer(userData);
        _output.add(writeBuffer.cast<Uint8>().asTypedList(userData.ref.size));
        malloc.free(writeBuffer);
        _bindings.transport_complete_write(_context, userData);
        calloc.free(userData);
        calloc.free(cqe);
      }
    });
  }

  void stop() {
    _subscription.cancel();
    _output.close();
    _input.close();
    _bindings.transport_close_descriptor(_descriptor);
    _active = false;
  }

  bool get active => _active;

  Stream<Uint8List> get bytesOutput => _output.stream;

  Stream<String> get stringOutput => _output.stream.map(_decoder.convert);

  Stream<Uint8List> get bytesInput => _input.stream;

  Stream<String> get stringInput => _input.stream.map(_decoder.convert);

  void queueRead({int size = 64, int position = 0, int offset = 0}) => _bindings.transport_queue_read(_context, _descriptor, size, offset);

  void queueWriteBytes(Uint8List bytes, {int position = 0, int offset = 0}) {
    final Pointer<Uint8> buffer = _bindings.transport_begin_write(_context, bytes.length).cast();
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    _bindings.transport_queue_write(_context, _descriptor, buffer.cast(), bytes.length, offset);
  }

  void queueWriteString(String string, {int position = 0, int offset = 0}) => queueWriteBytes(_encoder.convert(string), position: position, offset: offset);
}
