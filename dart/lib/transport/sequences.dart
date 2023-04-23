import 'dart:async';
import 'dart:collection';
import 'dart:ffi';

import 'bindings.dart';
import 'constants.dart';

class TransportSequences {
  final TransportBindings _bindings;
  final Queue<Completer<void>> _finalizers = Queue();
  final Pointer<transport_worker_t> _worker;

  TransportSequences(this._bindings, this._worker);

  @pragma(preferInlinePragma)
  void add(int sequenceId, int bufferId) => _bindings.transport_worker_sequence_add_buffer(_worker, sequenceId, bufferId);

  @pragma(preferInlinePragma)
  Pointer<transport_worker_sequence_element_t> last(int sequenceId) => _bindings.transport_worker_sequence_get_last_element(_worker, sequenceId);

  @pragma(preferInlinePragma)
  Pointer<transport_worker_sequence_element_t> first(int sequenceId) => _bindings.transport_worker_sequence_get_first_element(_worker, sequenceId);

  @pragma(preferInlinePragma)
  Pointer<transport_worker_sequence_element_t> next(int sequenceId, Pointer<transport_worker_sequence_element_t> iterator) => _bindings.transport_worker_sequence_get_next_element(
        _worker,
        sequenceId,
        iterator,
      );

  @pragma(preferInlinePragma)
  void drain(int sequenceId, int size, bool Function(Pointer<transport_worker_sequence_element_t> current) action) {
    var element = _bindings.transport_worker_sequence_get_first_element(_worker, sequenceId);
    if (!action(element)) {
      release(sequenceId, size);
      return;
    }
    for (var i = 0; i < size; i++) {
      final nextElement = next(sequenceId, element);
      _bindings.transport_worker_sequence_delete_element(_worker, sequenceId, element);
      if (!action(nextElement)) {
        release(sequenceId, size);
        return;
      }
      element = nextElement;
    }
    _bindings.transport_worker_release_sequence(_worker, sequenceId);
  }

  @pragma(preferInlinePragma)
  void release(int sequenceId, int size) {
    var element = _bindings.transport_worker_sequence_get_first_element(_worker, sequenceId);
    for (var i = 0; i < size; i++) {
      _bindings.transport_worker_sequence_release_element(_worker, sequenceId, element);
      element = next(sequenceId, element);
    }
    _bindings.transport_worker_release_sequence(_worker, sequenceId);
  }

  @pragma(preferInlinePragma)
  int? get() {
    final sequenceId = _bindings.transport_worker_get_sequence(_worker);
    if (sequenceId == transportBufferUsed) return null;
    return sequenceId;
  }

  Future<int> allocate() async {
    var sequenceId = _bindings.transport_worker_get_sequence(_worker);
    while (sequenceId == transportBufferUsed) {
      final completer = Completer();
      _finalizers.add(completer);
      await completer.future;
      sequenceId = _bindings.transport_worker_get_sequence(_worker);
    }
    return sequenceId;
  }
}
