import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'constants.dart';

class TransportServerChannel {
  final Pointer<transport_channel_t> pointer;
  final TransportBindings _bindings;

  TransportServerChannel(this.pointer, this._bindings);

  Future<void> read(int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(pointer);
    }
    _bindings.transport_channel_read(pointer, fd, bufferId, 0, transportEventRead);
  }

  Future<void> write(Uint8List bytes, int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(pointer);
    }
    final buffer = pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(pointer, fd, bufferId, 0, transportEventWrite);
  }
}

class TransportResourceChannel {
  final Pointer<transport_channel_t> pointer;
  final TransportBindings _bindings;

  TransportResourceChannel(this.pointer, this._bindings);

  Future<int> allocate() async {
    var bufferId = _bindings.transport_channel_allocate_buffer(pointer);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(pointer);
    }
    return bufferId;
  }

  void read(int fd, int bufferId, {int offset = 0}) {
    _bindings.transport_channel_read(pointer, fd, bufferId, offset, transportEventReadCallback);
  }

  void write(Uint8List bytes, int fd, int bufferId, {int offset = 0}) {
    final buffer = pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(pointer, fd, bufferId, offset, transportEventWriteCallback);
  }
}
