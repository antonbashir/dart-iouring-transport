import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/transport.dart';

import 'bindings.dart';
import 'constants.dart';

class TransportChannel {
  final Transport _transport;
  final int descriptor;
  final Pointer<transport_channel_t> _pointer;
  final TransportBindings _bindings;

  final _bufferFinalizers = Queue<Completer<int>>();

  TransportChannel(this._pointer, this._transport, this.descriptor, this._bindings);

  Future<int> allocate() async {
    var bufferId = _bindings.transport_channel_allocate_buffer(_pointer);
    if (bufferId == -1) {
      _transport.logger.info("Await buffer");
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      return await completer.future;
    }
    return bufferId;
  }

  void reset(int bufferId) {
    _bindings.memset(_pointer.ref.buffers[bufferId].iov_base, 0, _pointer.ref.buffer_size);
    _pointer.ref.buffers[bufferId].iov_len = _pointer.ref.buffer_size;
    _pointer.ref.used_buffers_offsets[bufferId] = 0;
  }

  void free(int bufferId) {
    _bindings.memset(_pointer.ref.buffers[bufferId].iov_base, 0, _pointer.ref.buffer_size);
    _pointer.ref.buffers[bufferId].iov_len = _pointer.ref.buffer_size;
    _pointer.ref.used_buffers_offsets[bufferId] = 0;
    _pointer.ref.used_buffers[bufferId] = transportBufferAvailable;
    if (_bufferFinalizers.isNotEmpty) _bufferFinalizers.removeFirst().complete(bufferId);
  }

  void close() => _bindings.transport_close_descritor(descriptor);
}

class TransportInboundChannel extends TransportChannel {
  TransportInboundChannel(super.pointer, super.transport, super.descriptor, super._fd) : super();

  Future<void> read({int offset = 0}) async {
    final bufferId = await allocate();
    _bindings.transport_channel_read(_pointer, descriptor, bufferId, offset, bufferId | transportEventRead);
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final bufferId = await allocate();
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, descriptor, bufferId, offset, bufferId | transportEventWrite);
  }
}

class TransportOutboundChannel extends TransportChannel {
  TransportOutboundChannel(super.pointer, super.transport, super.descriptor, super._bindings) : super();

  void read(int bufferId, int callbackId, {int offset = 0}) {
    _bindings.transport_channel_read(_pointer, descriptor, bufferId, offset, callbackId | transportEventReadCallback);
  }

  void write(Uint8List bytes, int bufferId, int callbackId, {int offset = 0}) {
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_channel_write(_pointer, descriptor, bufferId, offset, callbackId | transportEventWriteCallback);
  }
}
