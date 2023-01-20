library iouring_transport;

import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';

import 'transport/transport.dart';

Future<void> main(List<String> args) async {
  final transport = Transport();
  transport.initialize(TransportDefaults.configuration());
  final channel = transport.channel(TransportDefaults.channel());
  channel.start();
  final file = transport.file("test.txt");
  channel.writeString(file, "text\n");
  channel.outputBytes.listen((event) => print(File("test.txt").readAsStringSync()));
  while (true) {
    await Future.delayed(Duration(seconds: 1));
    channel.writeString(file, "text\n");
  }
}
