library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';

import 'transport/transport.dart';

Future<void> main(List<String> args) async {
  Transport()
    ..initialize(TransportDefaults.configuration())
    ..connection(TransportDefaults.loop()).bind("0.0.0.0", 1234).then((serverChannel) async {
      serverChannel.output.listen((event) => print("server:" + Utf8Decoder().convert(event)));
      while (true) {
        await Future.delayed(Duration(seconds: 1));
        serverChannel.queueRead(Utf8Encoder().convert("from client").length);
      }
    });
  Transport()
    ..initialize(TransportDefaults.configuration())
    ..connection(TransportDefaults.loop()).connect("127.0.0.1", 1234).then((clientChannel) async {
      clientChannel.output.listen((event) => print("client:" + Utf8Decoder().convert(event)));
      while (true) {
        await Future.delayed(Duration(seconds: 1));
        clientChannel.queueWrite(Utf8Encoder().convert("from client"));
      }
    });
}
