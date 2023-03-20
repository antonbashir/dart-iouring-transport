import 'dart:ffi';
import 'dart:isolate';

import 'bindings.dart';
import 'constants.dart';
import 'lookup.dart';

class TransportListener {
  final ReceivePort _fromTransport = ReceivePort();

  TransportListener(SendPort toTransport) {
    toTransport.send(_fromTransport.sendPort);
  }

  Future<void> listen() async {
    final configuration = await _fromTransport.first;

    final libraryPath = configuration[0] as String?;
    final listenerPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_listener_t>();
    final _ringSize = configuration[2] as int;
    final _workerPorts = configuration[3] as List<SendPort>;
    final _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);

    _fromTransport.close();

    final ring = listenerPointer.ref.ring;
    final cqes = _bindings.transport_allocate_cqes(_ringSize);
    while (true) {
      final cqeCount = _bindings.transport_wait(_ringSize, cqes, ring);
      final events = {};
      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          if (cqe.ref.user_data & transportEventMessage != 0) {
            _bindings.transport_listener_submit(listenerPointer, cqe.ref.res, cqe.ref.user_data & ~transportEventMessage);
            continue;
          }
          events[_bindings.transport_listener_get_worker_index(listenerPointer, cqe.ref.user_data)] = [
            cqe.ref.res,
            cqe.ref.user_data & ~listenerPointer.ref.worker_mask,
            listenerPointer.address,
          ];
        }
        events.forEach((key, value) => _workerPorts[key].send(value));
        _bindings.transport_cqe_advance(ring, cqeCount);
      }
    }
  }
}
