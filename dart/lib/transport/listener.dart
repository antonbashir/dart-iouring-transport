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
    final cqes = bindings.transport_allocate_cqes(ringSize);
    while (true) {
      bindings.transport_listener_reap(listenerPointer, cqes);
      for (var workerIndex = 0; workerIndex < workerPorts.length; workerIndex++) {
        if (listenerPointer.ref.ready_workers[workerIndex] == 1) {
          workerPorts[workerIndex].send(null);
          listenerPointer.ref.ready_workers[workerIndex] = 0;
        }
      }
    }
  }
}