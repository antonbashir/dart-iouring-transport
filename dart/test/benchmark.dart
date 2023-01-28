library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final serverTransport = Transport(TransportDefaults.transport(), TransportDefaults.controller())..initialize();
  final clientTransport = Transport(TransportDefaults.transport(), TransportDefaults.controller())..initialize();
  final done = Completer();

  var received = 0;
  var sent = 0;
  var seconds = 10;
  var stopChannels = false;

  final encoder = Utf8Encoder();

  serverTransport.connection(TransportDefaults.connection(), TransportDefaults.channel()).bind("0.0.0.0", 2525).listen((serverChannel) async {
    serverChannel.start(onRead: (payload) {
      received++;
      payload.finalize();
    });
    while (!stopChannels) {
      await Future.delayed(Duration.zero);
      serverChannel.queueRead();
      serverChannel.queueWrite(encoder.convert("from server"));
    }
    serverChannel.stop();
    done.complete();
  });

  clientTransport.connection(TransportDefaults.connection(), TransportDefaults.channel()).connect("127.0.0.1", 2525).listen((clientChannel) async {
    clientChannel.start(onWrite: (payload) {
      sent++;
      payload.finalize();
    });
    while (!stopChannels) {
      await Future.delayed(Duration.zero);
      clientChannel.queueRead();
      clientChannel.queueWrite(encoder.convert("from client"));
    }
    clientChannel.stop();
  });

  await Future.delayed(Duration(seconds: seconds));
  stopChannels = true;

  print("received RPS: ${received / seconds}");
  print("sent RPS: ${sent / seconds}");

  await done.future;
  serverTransport.close();
  clientTransport.close();
}
