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
    final ringSize = configuration[2] as int;
    final workerPorts = configuration[3] as List<SendPort>;
    final workers = configuration[4] as List<int>;
    final bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);

    _fromTransport.close();

    final events = <List<List<int>>>[];
    for (var workerIndex = 0; workerIndex < listenerPointer.ref.workers_count; workerIndex++) {
      listenerPointer.ref.workers[workerIndex] = workers[workerIndex];
      events.add([]);
    }

    final ring = listenerPointer.ref.ring;
    final cqes = bindings.transport_allocate_cqes(ringSize);

    while (true) {
      final cqeCount = bindings.transport_wait(ringSize, cqes, ring);

      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          if (cqe.ref.user_data & transportEventMessage != 0) {
            bindings.transport_listener_submit(listenerPointer, cqe.ref.res, cqe.ref.user_data & ~transportEventMessage);
            continue;
          }
          events[bindings.transport_listener_get_worker_index(listenerPointer, cqe.ref.user_data)].add([cqe.ref.res, cqe.ref.user_data & ~listenerPointer.ref.worker_mask]);
        }
        for (var workerIndex = 0; workerIndex < listenerPointer.ref.workers_count; workerIndex++) {
          final event = events[workerIndex];
          if (event.isNotEmpty) workerPorts[workerIndex].send(event);
          event.clear();
        }
        bindings.transport_cqe_advance(ring, cqeCount);
      }
    }
  }
}
