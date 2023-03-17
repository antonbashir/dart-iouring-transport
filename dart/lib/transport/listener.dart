import 'dart:ffi';
import 'dart:isolate';

import 'package:iouring_transport/transport/exception.dart';

import 'bindings.dart';
import 'lookup.dart';

class TransportListener {
  final ReceivePort fromTransport = ReceivePort();

  TransportListener(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> listen() async {
    final configuration = await fromTransport.first;

    final libraryPath = configuration[0] as String?;
    final _transport = Pointer.fromAddress(configuration[1] as int).cast<transport_t>();
    final _ringSize = configuration[2] as int;
    final out = configuration[3] as SendPort;
    final activator = configuration[4] as SendPort;
    final _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);

    fromTransport.close();

    final channelPointer = _bindings.transport_channel_initialize(_transport.ref.channel_configuration);
    if (channelPointer == nullptr) throw TransportException("Unable to create channel");
    final ring = channelPointer.ref.ring;
    final cqes = _bindings.transport_allocate_cqes(_ringSize);

    activator.send(channelPointer.address);

    while (true) {
      final cqeCount = _bindings.transport_wait(_ringSize, cqes, ring);
      final events = [];
      if (cqeCount != -1) {
        for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
          final cqe = cqes[cqeIndex];
          events.add([cqe.ref.res, cqe.ref.user_data, channelPointer.address]);
        }
        out.send(events);
        _bindings.transport_cqe_advance(ring, cqeCount);
      }
    }
  }
}
