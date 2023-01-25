library iouring_transport;

import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final serverTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();
  final clientTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();

  var received = 0;
  var sent = 0;
  var stop = false;

  serverTransport.connection().bind("0.0.0.0", 1234, TransportDefaults.channel()).listen((serverChannel) async {
    serverChannel.stringInput.listen((event) => received++);
    while (!stop) {
      await Future.delayed(Duration.zero);
      serverChannel.queueRead();
      serverChannel.queueWriteString("from server");
    }
  });

  clientTransport.connection().connect("127.0.0.1", 1234, TransportDefaults.channel()).listen((clientChannel) async {
    clientChannel.stringInput.listen((event) => sent++);
    while (!stop) {
      await Future.delayed(Duration.zero);
      clientChannel.queueRead();
      clientChannel.queueWriteString("from client");
    }
  });

  await Future.delayed(Duration(seconds: 30));
  stop = true;

  print("received RPS: ${received / 30}");
  print("sent RPS: ${received / 30}");
}
