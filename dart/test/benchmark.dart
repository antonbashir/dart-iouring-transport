library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final serverTransport = Transport(TransportDefaults.transport(), TransportDefaults.controller())..initialize();
  //final clientTransport = Transport(TransportDefaults.transport(), TransportDefaults.controller())..initialize();
  final done = Completer();

  var received = 0;
  var sent = 0;
  var seconds = 30;
  var stopChannels = false;

  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server");
  final fromClient = encoder.convert("from client");

  serverTransport.connection(TransportDefaults.acceptor(), TransportDefaults.channel()).bind("0.0.0.0", 9999).listen((serverChannel) async {
    serverChannel.start(
      onWrite: (payload) {
        payload.finalize();
        serverChannel.queueRead();
      },
      onRead: (payload) {
        payload.finalize();
        serverChannel.queueWrite(fromServer);
      },
    );
    serverChannel.queueRead();
  });

  // clientTransport.connection(TransportDefaults.connection(), TransportDefaults.channel()).connect("127.0.0.1", 9999).listen((clientChannel) async {
  //   clientChannel.start(
  //     onWrite: (payload) {
  //       sent++;
  //       payload.finalize();
  //       clientChannel.queueRead();
  //       //print("onWrite");
  //     },
  //     onRead: (payload) {
  //       payload.finalize();
  //       //print("onRead");
  //       if (!stopChannels) {
  //         clientChannel.queueWrite(fromClient);
  //         return;
  //       }
  //       clientChannel.stop();
  //     },
  //   );
  //   //print("onConnect");
  //   clientChannel.queueWrite(fromClient);
  // });

  await Future.delayed(Duration(days: 1));
  stopChannels = true;

  print("received RPS: ${received / seconds}");
  print("sent RPS: ${sent / seconds}");

  await done.future;
  serverTransport.close();
  //clientTransport.close();
}
