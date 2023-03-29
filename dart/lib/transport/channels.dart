import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'constants.dart';
import 'worker.dart';

class TransportChannel {
  final int _descriptor;
  final Pointer<transport_worker_t> _pointer;
  final TransportBindings _bindings;
  final TransportWorker worker;
  late final Queue<Completer<int>> _bufferFinalizers;

  late final Pointer<Int64> _usedBuffers;
  late final Pointer<iovec> _buffers;

  TransportChannel(this._pointer, this._descriptor, this._bindings, this._bufferFinalizers, this.worker) {
    _usedBuffers = _pointer.ref.used_buffers;
    _buffers = _pointer.ref.buffers;
  }

  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_select_buffer(_pointer);
    while (bufferId == -1) {
      final completer = Completer<int>();
      _bufferFinalizers.add(completer);
      bufferId = await completer.future;
      if (_usedBuffers[bufferId] == transportBufferAvailable) return bufferId;
      bufferId = _bindings.transport_worker_select_buffer(_pointer);
    }
    return bufferId;
  }

  void close() => _bindings.transport_close_descritor(_descriptor);
}

class TransportInboundChannel extends TransportChannel {
  TransportInboundChannel(super._pointer, super._descriptor, super._bindings, super._bufferFinalizers, super.worker) : super();

  Future<void> read() async {
    final bufferId = await allocate();
    final submitted = _bindings.transport_worker_read(_pointer, _descriptor, bufferId, 0, transportEventRead);
    worker.logger.debug("[inbound send read]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted =  $submitted");
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = await allocate();
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    final submitted = _bindings.transport_worker_write(_pointer, _descriptor, bufferId, 0, transportEventWrite);
    worker.logger.debug("[inbound send write]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted = $submitted");
  }
}

class TransportOutboundChannel extends TransportChannel {
  TransportOutboundChannel(super.pointer, super.descriptor, super._bindings, super._bufferFinalizers, super.worker) : super();

  void read(int bufferId, {int offset = 0}) {
    final submitted = _bindings.transport_worker_read(_pointer, _descriptor, bufferId, offset, transportEventReadCallback);
    worker.logger.debug("[outbound send read]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted = $submitted");
  }

  void write(Uint8List bytes, int bufferId, {int offset = 0}) {
    final buffer = _buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    final submitted = _bindings.transport_worker_write(_pointer, _descriptor, bufferId, offset, transportEventWriteCallback);
    worker.logger.debug("[outbound send write]: worker = ${_pointer.ref.id}, fd = ${_descriptor}, submitted = $submitted");
  }
}
