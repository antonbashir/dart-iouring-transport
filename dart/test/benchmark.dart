library iouring_transport;

import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final serverTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();
  final clientTransport = Transport(TransportDefaults.configuration(), TransportDefaults.loop())..initialize();
  final done = Completer();

  var received = 0;
  var sent = 0;
  var seconds = 10;
  var stopChannels = false;

  serverTransport.connection().bind("0.0.0.0", 1234, TransportDefaults.channel()).listen((serverChannel) async {
    serverChannel.stringInput.listen((event) => received++);
    while (!stopChannels) {
      await Future.delayed(Duration.zero);
      serverChannel.queueRead();
      serverChannel.queueWriteString("from server");
    }
    serverChannel.stop();
    done.complete();
  });

  clientTransport.connection().connect("127.0.0.1", 1234, TransportDefaults.channel()).listen((clientChannel) async {
    clientChannel.stringInput.listen((event) => sent++);
    while (!stopChannels) {
      await Future.delayed(Duration.zero);
      clientChannel.queueRead();
      clientChannel.queueWriteString("from client");
    }
    clientChannel.stop();
    done.complete();
  });

  await Future.delayed(Duration(seconds: seconds));
  stopChannels = true;
  await done.future;
  serverTransport.close();
  clientTransport.close();

  print("received RPS: ${received / seconds}");
  print("sent RPS: ${sent / seconds}");
}
