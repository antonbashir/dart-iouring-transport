import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

final Transport _transport = Transport(
  TransportDefaults.transport(),
  TransportDefaults.acceptor(),
  TransportDefaults.listener(),
  TransportDefaults.worker(),
  TransportDefaults.client(),
);

void main() {
  void Function(SendPort) worker = (port) async => print("initizlied");

  void spawn(void Function(SendPort) worker) => Isolate.spawn(worker, ReceivePort().sendPort);

  spawn(worker);
}
