import 'dart:ffi';
import 'dart:isolate';

import 'bindings.dart';
import 'lookup.dart';

class TransportIncomingListener {
  final ReceivePort fromTransport = ReceivePort();

  TransportIncomingListener(SendPort toTransport) {
    toTransport.send(fromTransport);
  }

  Future<void> listen() async {
    final configuration = await fromTransport.first;

    final libraryPath = configuration[0] as String?;
    final _transport = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    final _ringSize = configuration[2] as int;
    final out = configuration[3] as SendPort;
    final _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);

    fromTransport.close();

    final channelPointer = _bindings.transport_add_channel(_transport);
    final ring = channelPointer.ref.ring;
    final cqes = _bindings.transport_allocate_cqes(_ringSize);

    while (true) {
      final cqeCount = _bindings.transport_wait(_ringSize, cqes, ring);
      final events = [];
      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          events.add([cqe.ref.res, cqe.ref.user_data]);
        }
        out.send(events);
      }
    }
  }
}

class TransportOutgoingListener {
  final ReceivePort fromTransport = ReceivePort();

  TransportOutgoingListener(SendPort toTransport) {
    toTransport.send(fromTransport);
  }

  Future<void> listen() async {
    final configuration = await fromTransport.first;

    final libraryPath = configuration[0] as String?;
    final _transport = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    final _ringSize = configuration[2] as int;
    final out = configuration[3] as SendPort;
    final _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);

    fromTransport.close();

    final channelPointer = _bindings.transport_channel_initialize(_transport.ref.channel_configuration);
    final ring = channelPointer.ref.ring;
    final cqes = _bindings.transport_allocate_cqes(_ringSize);

    while (true) {
      final cqeCount = _bindings.transport_wait(_ringSize, cqes, ring);
      final events = [];
      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          events.add([cqe.ref.res, cqe.ref.user_data]);
        }
        out.send(events);
      }
    }
  }
}
