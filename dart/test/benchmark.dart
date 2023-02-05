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
  var seconds = 30;
  var stopChannels = false;

  final encoder = Utf8Encoder();

  serverTransport.connection(TransportDefaults.connection(), TransportDefaults.channel()).bind("0.0.0.0", 9999).listen((serverChannel) async {
    serverChannel.start(
      onWrite: (payload) {
        payload.finalize();
        serverChannel.queueRead();
        //print("onWrite");
      },
      onRead: (payload) {
        received++;
        payload.finalize();
        //print("onRead");
        if (!stopChannels) {
          serverChannel.queueWrite(encoder.convert("from server"));
          return;
        }
        serverChannel.stop();
        done.complete();
      },
    );
    //print("onAccept");
    serverChannel.queueRead();
  });

  clientTransport.connection(TransportDefaults.connection(), TransportDefaults.channel()).connect("127.0.0.1", 9999).listen((clientChannel) async {
    clientChannel.start(
      onWrite: (payload) {
        sent++;
        payload.finalize();
        clientChannel.queueRead();
        //print("onWrite");
      },
      onRead: (payload) {
        payload.finalize();
        //print("onRead");
        if (!stopChannels) {
          clientChannel.queueWrite(encoder.convert("from client"));
          return;
        }
        clientChannel.stop();
      },
    );
    //print("onConnect");
    clientChannel.queueWrite(encoder.convert("from client"));
  });

  await Future.delayed(Duration(seconds: seconds));
  stopChannels = true;

  print("received RPS: ${received / seconds}");
  print("sent RPS: ${sent / seconds}");

  await done.future;
  serverTransport.close();
  clientTransport.close();
}
