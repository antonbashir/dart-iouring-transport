library iouring_transport;

import 'dart:async';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final serverTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();
  final clientTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();

  serverTransport.connection().bind("0.0.0.0", 1234, TransportDefaults.channel()).listen((serverChannel) async {
    serverChannel.stringInput.listen((event) => print("from client: $event"));
    while (true) {
      serverChannel.queueRead();
      serverChannel.queueWriteString("from server");
      await Future.delayed(Duration.zero);
    }
  });

  clientTransport.connection().connect("127.0.0.1", 1234, TransportDefaults.channel()).listen((clientChannel) async {
    clientChannel.stringInput.listen((event) => print("from server: $event"));
    while (true) {
      clientChannel.queueRead();
      clientChannel.queueWriteString("from client");
      await Future.delayed(Duration.zero);
    }
  });
}
