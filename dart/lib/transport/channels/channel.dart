import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/listener.dart';

import '../bindings.dart';
import '../payload.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<transport_channel_context_t> _context;
  final TransportListener _listener;
  final TransportChannelConfiguration _configuration;
  final StreamController<TransportPayload> _output = StreamController();
  final StreamController<TransportPayload> _input = StreamController();
  final _decoder = Utf8Decoder();
  final _encoder = Utf8Encoder();
  late StreamSubscription<Pointer<io_uring_cqe>> _subscription;
  bool _active = false;
  void Function() onStop = () {};

  TransportChannel(this._bindings, this._context, this._listener, this._configuration);

  void start({void Function()? onStop}) {
    _active = true;
    _subscription = _listener.cqes.listen(_handleCqe);
    if (onStop != null) this.onStop = onStop;
  }

  void stop() {
    _subscription.cancel();
    _output.close();
    _input.close();
    _bindings.transport_close_channel(_context);
    _active = false;
    onStop();
  }

  bool get active => _active;

  Stream<Uint8List> get bytesOutput => _output.stream.map((event) => event.bytes);

  Stream<String> get stringOutput => _output.stream.map((event) {
        final String string = _decoder.convert(event.bytes);
        event.finalize();
        return string;
      });

  Stream<Uint8List> get bytesInput => _input.stream.map((event) => event.bytes);

  Stream<String> get stringInput => _input.stream.map((event) {
        final String string = _decoder.convert(event.bytes);
        event.finalize();
        return string;
      });

  Future<void> queueRead({int offset = 0}) async {
    while (_bindings.transport_prepare_read(_context, _configuration.messageSize) == nullptr) {
      await Future.delayed(_configuration.bufferAvailableAwaitDelayed);
    }
    _bindings.transport_queue_read(_context, _configuration.messageSize, offset);
  }

  Future<void> queueWriteBytes(Uint8List bytes, {int offset = 0}) async {
    Pointer<Uint8> buffer = _bindings.transport_prepare_write(_context, _configuration.messageSize).cast();
    while (buffer == nullptr) {
      await Future.delayed(_configuration.bufferAvailableAwaitDelayed);
      buffer = _bindings.transport_prepare_write(_context, _configuration.messageSize).cast();
    }
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    _bindings.transport_queue_write(_context, bytes.length, _configuration.messageSize, offset);
  }

  void queueWriteString(String string, {int offset = 0}) => queueWriteBytes(_encoder.convert(string), offset: offset);

  int currentReadSize() => _context.ref.current_read_size;

  int currentWriteSize() => _context.ref.current_write_size;

  void _handleCqe(Pointer<io_uring_cqe> cqe) {
    Pointer<transport_data_message> userData = Pointer.fromAddress(cqe.ref.user_data);
    if (userData == nullptr) return;
    if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_READ && userData.ref.fd == _context.ref.fd) {
      final readBuffer = _bindings.transport_extract_read_buffer(_context, userData);
      final bytes = readBuffer.cast<Uint8>().asTypedList(cqe.ref.res);
      final payload = TransportPayload(_bindings, _bindings.transport_create_payload(_context, readBuffer, userData), bytes);
      _input.add(payload);
      if (!_input.hasListener) payload.finalize();
      _bindings.transport_free_message(_context.ref.owner, userData.cast(), userData.ref.type);
      _bindings.transport_free_cqe(_context.ref.owner, cqe);
    }
    if (userData.ref.type == transport_message_type.TRANSPORT_MESSAGE_WRITE && userData.ref.fd == _context.ref.fd) {
      final writeBuffer = _bindings.transport_extract_write_buffer(_context, userData);
      final bytes = writeBuffer.cast<Uint8>().asTypedList(cqe.ref.res);
      final payload = TransportPayload(_bindings, _bindings.transport_create_payload(_context, writeBuffer, userData), bytes);
      _output.add(payload);
      if (!_output.hasListener) payload.finalize();
      _bindings.transport_free_message(_context.ref.owner, userData.cast(), userData.ref.type);
      _bindings.transport_free_cqe(_context.ref.owner, cqe);
    }
  }
}
