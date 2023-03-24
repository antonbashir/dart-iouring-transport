import 'dart:ffi';
import 'dart:isolate';

import 'bindings.dart';
import 'lookup.dart';

class TransportListener {
  final ReceivePort _fromTransport = ReceivePort();

  TransportListener(SendPort toTransport) {
    toTransport.send(_fromTransport.sendPort);
  }

  Future<void> initialize() async {
    final configuration = await _fromTransport.first;
    final libraryPath = configuration[0] as String?;
    final listenerPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_listener_t>();
    final ringSize = configuration[2] as int;
    final workerPorts = configuration[3] as List<SendPort>;
    final bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _fromTransport.close();
    final ring = listenerPointer.ref.ring;
    final cqes = bindings.transport_allocate_cqes(ringSize);
    final events = workerPorts.map((_) => <List<dynamic>>[]).toList();
    while (true) {
      final cqeCount = bindings.transport_wait(ringSize, cqes, ring);

      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          if (bindings.transport_listener_is_internal_data(cqe)) {
            bindings.transport_listener_prepare_data(listenerPointer, cqe.ref.res, cqe.ref.user_data);
            continue;
          }
          if (bindings.transport_listener_is_internal_result(cqe)) {
            bindings.transport_listener_prepare_result(listenerPointer, cqe.ref.res, cqe.ref.user_data);
            continue;
          }

          events[bindings.transport_listener_get_worker_index(cqe.ref.user_data)].add([cqe.ref.res, cqe.ref.user_data]);
        }
        for (var workerIndex = 0; workerIndex < workerPorts.length; workerIndex++) {
          workerPorts[workerIndex].send(events[workerIndex]);
          events[workerIndex].clear();
        }
        bindings.transport_listener_submit(listenerPointer);
        bindings.transport_cqe_advance(ring, cqeCount);
      }
    }
  }
}
