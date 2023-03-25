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
    final events = workerPorts.map((_) => <dynamic>[]).toList();
    while (true) {
      final cqeCount = bindings.transport_wait(ringSize, cqes, ring);
      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          final result = cqe.ref.res;
          final userData = cqe.ref.user_data;
          events[result].add(userData);
        }
        for (var workerIndex = 0; workerIndex < workerPorts.length; workerIndex++) {
          final workerEvents = events[workerIndex];
          workerPorts[workerIndex].send(workerEvents);
          workerEvents.clear();
        }
        bindings.transport_cqe_advance(ring, cqeCount);
      }
    }
  }
}
