import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'constants.dart';

class TransportChannel {
  final int _fd;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;

  late final Queue<Completer<int>> _bufferFinalizers;
  late final Pointer<iovec> _buffers;

  TransportChannel(this._workerPointer, this._fd, this._bindings, this._bufferFinalizers) {
    _buffers = _workerPointer.ref.buffers;
  }

  @pragma(preferInlinePragma)
  int? getBuffer() {
    final buffer = _bindings.transport_worker_get_buffer(_workerPointer);
    if (buffer == transportBufferUsed) return null;
    return buffer;
  }

  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_get_buffer(_workerPointer);
    while (bufferId == transportBufferUsed) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      await completer.future;
      bufferId = _bindings.transport_worker_get_buffer(_workerPointer);
    }
    return bufferId;
  }

  @pragma(preferInlinePragma)
  void read(int bufferId, int timeout, {int offset = 0}) {
    _bindings.transport_worker_read(_workerPointer, _fd, bufferId, offset, timeout, transportEventRead | transportEventClient);
  }

  @pragma(preferInlinePragma)
  void write(Uint8List bytes, int bufferId, int timeout, {int offset = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_write(_workerPointer, _fd, bufferId, offset, timeout, transportEventWrite | transportEventClient);
  }

  @pragma(preferInlinePragma)
  void receiveMessage(int bufferId, int socketFamily, int timeout, int flags) {
    _bindings.transport_worker_receive_message(
      _workerPointer,
      _fd,
      bufferId,
      socketFamily,
      flags,
      timeout,
      transportEventReceiveMessage | transportEventClient,
    );
  }

  @pragma(preferInlinePragma)
  void sendMessage(Uint8List bytes, int bufferId, int socketFamily, Pointer<sockaddr> destination, int timeout, int flags) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_send_message(
      _workerPointer,
      _fd,
      bufferId,
      destination,
      socketFamily,
      flags,
      timeout,
      transportEventSendMessage | transportEventClient,
    );
  }

  @pragma(preferInlinePragma)
  void respondMessage(Uint8List bytes, int bufferId, int socketFamily, int timeout, int flags) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_respond_message(
      _workerPointer,
      _fd,
      bufferId,
      socketFamily,
      flags,
      timeout,
      transportEventSendMessage | transportEventClient,
    );
  }

  @pragma(preferInlinePragma)
  void close() => _bindings.transport_close_descritor(_fd);
}
