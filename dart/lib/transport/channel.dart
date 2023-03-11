import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'logger.dart';

class TransportChannel {
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;
  final TransportLogger _logger;

  FutureOr<Uint8List> Function(Uint8List payload, int fd)? onRead;
  FutureOr<void> Function(Uint8List payload, int fd)? onWrite;

  TransportChannel(this._pointer, this._bindings, this._logger, {this.onRead, this.onWrite});

  Future<void> read(int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    _bindings.transport_channel_read(_pointer, fd, bufferId);
  }

  Future<void> write(Uint8List bytes, int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId);
  }

  @pragma("vm:prefer-inline")
  Future<void> handleRead(int fd, int size) async {
    if (onRead == null) {
      _bindings.transport_channel_complete_read_by_fd(_pointer, fd);
      return;
    }
    final bufferId = _bindings.transport_channel_handle_read(_pointer, fd, size);
    final buffer = _pointer.ref.buffers[bufferId];
    final result = onRead!(buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len), fd);
    if (result is Future<Uint8List>) {
      return result.then((resultBytes) {
        _bindings.transport_channel_complete_read_by_buffer_id(_pointer, bufferId);
        buffer.iov_base.cast<Uint8>().asTypedList(resultBytes.length).setAll(0, resultBytes);
        buffer.iov_len = resultBytes.length;
        _bindings.transport_channel_write(_pointer, fd, bufferId);
      });
    }
    _bindings.transport_channel_complete_read_by_buffer_id(_pointer, bufferId);
    buffer.iov_base.cast<Uint8>().asTypedList(result.length).setAll(0, result);
    buffer.iov_len = result.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId);
  }

  @pragma("vm:prefer-inline")
  Future<void> handleWrite(int fd, int size) async {
    if (onWrite == null) {
      _bindings.transport_channel_complete_write_by_fd(_pointer, fd);
      return;
    }
    final bufferId = _bindings.transport_channel_handle_write(_pointer, fd, size);
    final buffer = _pointer.ref.buffers[bufferId];
    final result = onWrite!(buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len), fd);
    if (result is Future<void>) {
      return result.then((_) => _bindings.transport_channel_complete_write_by_buffer_id(_pointer, fd, bufferId));
    }
    _bindings.transport_channel_complete_write_by_buffer_id(_pointer, fd, bufferId);
  }
}
