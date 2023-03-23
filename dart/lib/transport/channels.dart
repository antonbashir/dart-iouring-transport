import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'constants.dart';

class TransportChannel {
  final int descriptor;
  final Pointer<transport_worker_t> _pointer;
  final TransportBindings _bindings;

  static final _bufferFinalizers = <int, Queue<Completer<int>>>{};

  TransportChannel(this._pointer, this.descriptor, this._bindings) {
    _bufferFinalizers[this._pointer.address] = Queue();
  }

  @pragma(preferInlinePragma)
  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_select_buffer(_pointer);
    if (bufferId == -1) {
      final completer = Completer<int>();
      _bufferFinalizers[_pointer.address]!.add(completer);
      return await completer.future;
    }
    return bufferId;
  }

  @pragma(preferInlinePragma)
  void reuse(int bufferId) {
    _bindings.memset(_pointer.ref.buffers[bufferId].iov_base, 0, _pointer.ref.buffer_size);
    _pointer.ref.buffers[bufferId].iov_len = _pointer.ref.buffer_size;
    _pointer.ref.used_buffers_offsets[bufferId] = 0;
  }

  @pragma(preferInlinePragma)
  void free(int bufferId) {
    _bindings.memset(_pointer.ref.buffers[bufferId].iov_base, 0, _pointer.ref.buffer_size);
    _pointer.ref.buffers[bufferId].iov_len = _pointer.ref.buffer_size;
    _pointer.ref.used_buffers_offsets[bufferId] = 0;
    _pointer.ref.used_buffers[bufferId] = transportBufferAvailable;
    final finalizer = _bufferFinalizers[_pointer.address]!;
    if (finalizer.isNotEmpty) finalizer.removeFirst().complete(bufferId);
  }

  void close() => _bindings.transport_close_descritor(descriptor);
}

class TransportInboundChannel extends TransportChannel {
  TransportInboundChannel(super.pointer, super.descriptor, super._bindings) : super();

  Future<void> read({int offset = 0}) async {
    final bufferId = await allocate();
    _bindings.transport_worker_read(_pointer, descriptor, bufferId, offset, transportEventRead);
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final bufferId = await allocate();
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_write(_pointer, descriptor, bufferId, offset, transportEventWrite);
  }
}

class TransportOutboundChannel extends TransportChannel {
  TransportOutboundChannel(super.pointer, super.descriptor, super._bindings) : super();

  void read(int bufferId, {int offset = 0}) {
    _bindings.transport_worker_read(_pointer, descriptor, bufferId, offset, transportEventReadCallback);
  }

  void write(Uint8List bytes, int bufferId, {int offset = 0}) {
    final buffer = _pointer.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_write(_pointer, descriptor, bufferId, offset, transportEventWriteCallback);
  }
}
