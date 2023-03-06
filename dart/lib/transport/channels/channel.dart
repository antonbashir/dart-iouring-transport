import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../bindings.dart';
import '../payload.dart';

class TransportChannel {
  final payloadPool = <int, TransportDataPayload>{};
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;

  FutureOr Function(TransportDataPayload payload)? _onRead;
  FutureOr Function(TransportDataPayload payload)? _onWrite;

  TransportChannel(
    this._pointer,
    this._bindings, {
    FutureOr Function(TransportDataPayload payload)? onRead,
    FutureOr Function(TransportDataPayload payload)? onWrite,
  }) {
    this._onRead = onRead;
    this._onWrite = onWrite;
    for (var bufferId = 0; bufferId < _pointer.ref.buffers_count; bufferId++) {
      payloadPool[bufferId] = TransportDataPayload(this, bufferId);
    }
  }

  Future<void> read(int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    _bindings.transport_channel_read(_pointer, fd, bufferId);
  }

  void write(Uint8List bytes, int fd, int bufferId) {
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId);
  }

  Future<void> handleRead(int fd, int size) async {
    if (_onRead == null) {
      _bindings.transport_channel_complete_read_by_fd(_pointer, fd);
      return;
    }
    final bufferId = _bindings.transport_channel_handle_read(_pointer, fd, size);
    final buffer = _pointer.ref.buffers[bufferId];
    final payload = payloadPool[bufferId]!;
    payload.fd = fd;
    payload.bytes = buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len);
    payload.finalizer = (payload) => _bindings.transport_channel_complete_read_by_buffer_id(
          _pointer,
          bufferId,
        );
    await _onRead!(payload);
  }

  Future<void> handleWrite(int fd, int size) async {
    if (_onWrite == null) {
      _bindings.transport_channel_complete_write_by_fd(_pointer, fd);
      return;
    }
    final bufferId = _bindings.transport_channel_handle_write(_pointer, fd, size);
    final buffer = _pointer.ref.buffers[bufferId];
    final payload = payloadPool[bufferId]!;
    payload.fd = fd;
    payload.bytes = buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len);
    payload.finalizer = (payload) => _bindings.transport_channel_complete_write_by_buffer_id(
          _pointer,
          fd,
          bufferId,
        );
    await _onWrite!(payload);
  }
}
