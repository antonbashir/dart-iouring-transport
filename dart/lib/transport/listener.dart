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

    for (var workerIndex = 0; workerIndex < listenerPointer.ref.workers_count; workerIndex++) {
      listenerPointer.ref.workers[workerIndex] = workers[workerIndex];
    }

    final registerResult = bindings.transport_listener_register_buffers(listenerPointer);
    if (registerResult != 0) {
      print(registerResult);
    }

    final ring = listenerPointer.ref.ring;
    final cqes = bindings.transport_allocate_cqes(ringSize);

    while (true) {
      final cqeCount = bindings.transport_wait(ringSize, cqes, ring);

      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          if (cqe.ref.user_data & transportEventMessage != 0) {
            bindings.transport_listener_prepare(listenerPointer, cqe.ref.res, cqe.ref.user_data & ~transportEventMessage);
            continue;
          }
          final workerIndex = (cqe.ref.user_data >> 16) & 0xffffffff;
          print(workerIndex);
          workerPorts[workerIndex].send([cqe.ref.res, cqe.ref.user_data]);
        }
        bindings.transport_listener_submit(listenerPointer);
        bindings.transport_cqe_advance(ring, cqeCount);
      }
    }
  }
}
