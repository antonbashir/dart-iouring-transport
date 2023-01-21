library iouring_transport;

import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  if (!File("test.txt").existsSync()) File("test.txt").createSync();
  await Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..file("test.txt").writeString("test");
  await Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..file("test.txt").readString().then(print);
  File("test.txt").deleteSync();
  Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..connection().bind("0.0.0.0", 1234).listen((serverChannel) async {
      serverChannel.stringOutput.listen((event) => print("server: $event"));
      while (true) {
        await Future.delayed(Duration(seconds: 1));
        serverChannel.queueRead();
        serverChannel.queueWriteString("from server");
      }
    });
  Transport(TransportDefaults.configuration(), TransportDefaults.loop())
    ..initialize()
    ..connection().connect("127.0.0.1", 1234).listen((clientChannel) async {
      clientChannel.stringOutput.listen((event) => print("client: $event"));
      while (true) {
        await Future.delayed(Duration(seconds: 1));
        clientChannel.queueRead();
        clientChannel.queueWriteString("from client");
      }
    });
}
