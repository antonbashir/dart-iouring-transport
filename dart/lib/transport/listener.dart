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
    final transportPointer = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    final listenerPointer = Pointer.fromAddress(configuration[2] as int).cast<transport_listener_t>();
    final ringSize = configuration[3] as int;
    final workerPorts = configuration[4] as List<SendPort>;
    final bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
    _fromTransport.close();
    //final logger = TransportLogger(TransportLogLevel.values[transportPointer.ref.transport_configuration.ref.log_level]);
    final cqes = bindings.transport_allocate_cqes(ringSize);
    while (true) {
      if (!bindings.transport_listener_reap(listenerPointer, cqes)) {
        //final id = listenerPointer.ref.id;
        bindings.transport_listener_destroy(listenerPointer);
        //logger.debug("[listener ${id}]: closed");
        Isolate.exit();
      }
      for (var workerIndex = 0; workerIndex < workerPorts.length; workerIndex++) {
        if (listenerPointer.ref.ready_workers[workerIndex] != 0) {
          workerPorts[workerIndex].send(null);
          listenerPointer.ref.ready_workers[workerIndex] = 0;
        }
      }
    }
  }
}
