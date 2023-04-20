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

  TransportBuffers(this._bindings, this.buffers, this._worker);

  @pragma(preferInlinePragma)
  bool available() => _bindings.transport_worker_has_free_buffer(_worker);

  @pragma(preferInlinePragma)
  void release(int bufferId) {
    _bindings.transport_worker_release_buffer(_worker, bufferId);
    if (_finalizers.isNotEmpty) _finalizers.removeLast().complete();
  }

  @pragma(preferInlinePragma)
  void reuse(int bufferId) {
    _bindings.transport_worker_reuse_buffer(_worker, bufferId);
  }

  @pragma(preferInlinePragma)
  Uint8List read(int bufferId, int length) {
    final buffer = buffers[bufferId];
    final bufferBytes = buffer.iov_base.cast<Uint8>();
    return bufferBytes.asTypedList(length);
  }

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
      print("wait buffer");
      await completer.future;
      bufferId = _bindings.transport_worker_get_buffer(_worker);
    }
    return bufferId;
  }
}
