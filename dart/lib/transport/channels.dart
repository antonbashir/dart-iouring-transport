import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/transport.dart';

import 'bindings.dart';
import 'constants.dart';

class TransportChannel {
  static final _channels = <int, TransportChannel>{};

  final Transport _transport;
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;

  TransportChannel(this._pointer, this._bindings, this._transport) {
    _channels[_pointer.address] = this;
  }

  Future<int> allocate() async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    while (bufferId == -1) {
      _transport.logger.info("Await buffer");
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    }
    return bufferId;
  }

  @pragma(preferInlinePragma)
  void free(int bufferId) {
    _bindings.memset(_pointer.ref.buffers[bufferId].iov_base, 0, _pointer.ref.buffer_size);
    _pointer.ref.buffers[bufferId].iov_len = _pointer.ref.buffer_size;
    _pointer.ref.used_buffers_offsets[bufferId] = 0;
  }

  @pragma(preferInlinePragma)
  static TransportChannel channel(int pointer) => _channels[pointer]!;
}

class TransportServerChannel extends TransportChannel {
  final int _bufferId;
  TransportServerChannel(super.pointer, this._bufferId, super.transport, super._bindings) : super();

  void read(int fd, {int offset = 0}) {
    _bindings.transport_channel_read(_pointer, fd, _bufferId, offset, transportEventRead);
  }

  void write(Uint8List bytes, int fd, {int offset = 0}) {
    final buffer = _pointer.ref.buffers[_bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, _bufferId, offset, transportEventWrite);
  }
}

class TransportResourceChannel extends TransportChannel {
  TransportResourceChannel(super.pointer, super.transport, super._bindings) : super();

  void read(int fd, int bufferId, {int offset = 0}) {
    _bindings.transport_channel_read(_pointer, fd, bufferId, offset, transportEventReadCallback);
  }

  void write(Uint8List bytes, int fd, int bufferId, {int offset = 0}) {
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, fd, bufferId, offset, transportEventWriteCallback);
  }
}
