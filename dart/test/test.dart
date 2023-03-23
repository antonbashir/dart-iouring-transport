import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:test/test.dart';

final Transport _transport = Transport(
  TransportDefaults.transport(),
  TransportDefaults.acceptor(),
  TransportDefaults.channel(),
  TransportDefaults.client(),
);

void main() {
  void Function(SendPort) worker = (port) async => print("initizlied");

  void spawn(void Function(SendPort) worker) => Isolate.spawn(worker, ReceivePort().sendPort);

  spawn(worker);
}
