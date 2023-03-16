library iouring_transport;

import 'dart:async';
import 'dart:convert';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server\n");

  Transport()
    ..initialize(
      TransportDefaults.transport(),
      TransportDefaults.acceptor(),
      TransportDefaults.channel(),
    )
    ..run(inboundIsolates: 4, outboundIsolates: 4).then((loop) async {
      loop.serve("0.0.0.0", 9000, onAccept: (channel, descriptor) => channel.read(descriptor)).listen((event) async {
        event.respond(fromServer);
      });
    });

  await Future.delayed(Duration(days: 1));
}
