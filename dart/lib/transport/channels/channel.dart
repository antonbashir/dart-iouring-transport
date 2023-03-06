import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import '../bindings.dart';
import '../payload.dart';

class TransportChannel {
  final payloadPool = <int, TransportDataPayload>{};
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;

  void Function(TransportDataPayload payload)? _onRead;
  void Function(TransportDataPayload payload)? _onWrite;
  void Function()? _onStop;

  TransportChannel(
    this._pointer,
    this._bindings, {
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    this._onRead = onRead;
    this._onWrite = onWrite;
    this._onStop = onStop;
    for (var bufferId = 0; bufferId < _pointer.ref.buffers_count; bufferId++) {
      payloadPool[bufferId] = TransportDataPayload(this, bufferId);
    }
  }

  void stop() {
    _bindings.transport_channel_close(_pointer);
    _onStop?.call();
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
    Pointer<iovec> data = _bindings.transport_channel_get_buffer(_pointer, bufferId);
    data.ref.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    data.ref.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId);
  }

  void handleRead(int fd, int bufferId) {
    if (_onRead == null) {
      _bindings.transport_channel_free_buffer(_pointer, bufferId);
      return;
    }
    final buffer = _bindings.transport_channel_get_buffer(_pointer, bufferId);
    final payload = payloadPool[bufferId]!;
    payload.fd = fd;
    payload.bytes = buffer.ref.iov_base.cast<Uint8>().asTypedList(buffer.ref.iov_len);
    payload.finalizer = (payload) => _bindings.transport_channel_free_buffer(_pointer, bufferId);
    _onRead!(payload);
  }

  void handleWrite(int fd, int bufferId) {
    if (_onWrite == null) {
      _bindings.transport_channel_free_buffer(_pointer, bufferId);
      _bindings.transport_channel_read(_pointer, fd, bufferId);
      return;
    }
    final buffer = _bindings.transport_channel_get_buffer(_pointer, bufferId);
    final payload = payloadPool[bufferId]!;
    payload.fd = fd;
    payload.bytes = buffer.ref.iov_base.cast<Uint8>().asTypedList(buffer.ref.iov_len);
    payload.finalizer = (payload) {
      _bindings.transport_channel_free_buffer(_pointer, bufferId);
      _bindings.transport_channel_read(_pointer, fd, bufferId);
    };
    _onWrite!(payload);
  }
}
