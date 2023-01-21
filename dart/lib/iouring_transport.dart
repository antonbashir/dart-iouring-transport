library iouring_transport;

import 'dart:async';
import 'dart:convert';

import 'package:iouring_transport/transport/defaults.dart';

import 'transport/transport.dart';

Future<void> main(List<String> args) async {
  Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..connection().bind("0.0.0.0", 1234).listen((serverChannel) async {
      serverChannel.output.listen((event) => print("server:" + Utf8Decoder().convert(event)));
      while (true) {
        await Future.delayed(Duration(seconds: 1));
        serverChannel.queueRead(Utf8Encoder().convert("from client").length);
      }
    });
  Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..connection().connect("127.0.0.1", 1234).listen((clientChannel) async {
      clientChannel.output.listen((event) => print("client:" + Utf8Decoder().convert(event)));
      while (true) {
        await Future.delayed(Duration(seconds: 1));
        clientChannel.queueWrite(Utf8Encoder().convert("from client"));
      }
    });
}
