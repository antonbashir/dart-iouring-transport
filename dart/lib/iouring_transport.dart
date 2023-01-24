library iouring_transport;

import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final fileTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();
  final serverTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();
  final clientTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();

  if (!File("test.txt").existsSync()) File("test.txt").createSync();
  await fileTransport.file("test.txt", TransportDefaults.channel()).writeString("test");
  await fileTransport.file("test.txt", TransportDefaults.channel()).readString().then(print);
  File("test.txt").deleteSync();

  serverTransport.connection().bind("0.0.0.0", 1234, TransportDefaults.channel()).listen((serverChannel) async {
    serverChannel.stringInput.listen((event) => print("server: $event"));
    while (true) {
      await Future.delayed(Duration(seconds: 1));
      serverChannel.queueRead();
      serverChannel.queueWriteString("from server");
    }
  });

  clientTransport.connection().connect("127.0.0.1", 1234, TransportDefaults.channel()).listen((clientChannel) async {
    clientChannel.stringInput.listen((event) => print("client: $event"));
    while (true) {
      await Future.delayed(Duration(seconds: 1));
      clientChannel.queueRead();
      clientChannel.queueWriteString("from client");
    }
  });
}
