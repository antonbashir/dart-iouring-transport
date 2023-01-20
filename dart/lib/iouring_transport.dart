library iouring_transport;

import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';

import 'transport/transport.dart';

Future<void> main(List<String> args) async {
  final transport = Transport();
  transport.initialize(TransportDefaults.configuration());
  final channel = transport.channel(TransportDefaults.channel());
  channel.writeToFile("test.txt", "test");
  channel.start();
  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }
}
