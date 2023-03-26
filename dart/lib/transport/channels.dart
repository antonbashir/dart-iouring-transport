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

  late final int _bufferSize;
  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;

  static final _bufferFinalizers = <int, Queue<Completer<int>>>{};

  TransportChannel(this._pointer, this.descriptor, this._bindings) {
    _bufferFinalizers[this._pointer.address] = Queue();
    _bufferSize = _pointer.ref.buffer_size;
    _usedBuffers = _pointer.ref.used_buffers;
    _buffers = _pointer.ref.buffers;
  }

  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_select_buffer(_pointer);
    while (bufferId == -1) {
      final completer = Completer<int>();
      _bufferFinalizers[_pointer.address]!.add(completer);
      bufferId = await completer.future;
      if (_usedBuffers[bufferId] == transportBufferAvailable) return bufferId;
      bufferId = _bindings.transport_worker_select_buffer(_pointer);
    }
    return bufferId;
  }

  void free(int bufferId) {
    _bindings.transport_worker_free_buffer(_pointer, bufferId);
    final finalizer = _bufferFinalizers[_pointer.address]!;
    if (finalizer.isNotEmpty) finalizer.removeLast().complete(bufferId);
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
    final buffer = _buffers[bufferId];
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
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_worker_write(_pointer, descriptor, bufferId, offset, transportEventWriteCallback);
  }
}
