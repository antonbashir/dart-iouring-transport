import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'constants.dart';

class TransportBuffers {
  final TransportBindings _bindings;
  final Pointer<iovec> buffers;
  final Queue<Completer<void>> _finalizers = Queue();
  final Pointer<transport_worker_t> _worker;

  late final int bufferSize;

  TransportBuffers(this._bindings, this.buffers, this._worker) {
    bufferSize = _worker.ref.buffer_size;
  }

  @pragma(preferInlinePragma)
  void release(int bufferId) {
    _bindings.transport_worker_release_buffer(_worker, bufferId);
    if (_finalizers.isNotEmpty) _finalizers.removeLast().complete();
  }

  @pragma(preferInlinePragma)
  Uint8List read(int bufferId) {
    final buffer = buffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    return bufferBytes.asTypedList(buffer.iov_len);
  }

  @pragma(preferInlinePragma)
  void setLength(int bufferId, int length) => buffers[bufferId].iov_len = length;

  @pragma(preferInlinePragma)
  void write(int bufferId, Uint8List bytes) {
    final buffer = buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
  }

  @pragma(preferInlinePragma)
  int? get() {
    final buffer = _bindings.transport_worker_get_buffer(_worker);
    if (buffer == transportBufferUsed) return null;
    return buffer;
  }

  Future<int> allocate() async {
    var bufferId = _bindings.transport_worker_get_buffer(_worker);
    while (bufferId == transportBufferUsed) {
      final completer = Completer();
      _finalizers.add(completer);
      await completer.future;
      bufferId = _bindings.transport_worker_get_buffer(_worker);
    }
    return bufferId;
  }

  Future<List<int>> allocateArray(int count) async {
    final bufferIds = <int>[];
    for (var index = 0; index < count; index++) bufferIds.add(get() ?? await allocate());
    return bufferIds;
  }

  @pragma(preferInlinePragma)
  void releaseArray(List<int> buffers) {
    for (var id in buffers) release(id);
  }
}
