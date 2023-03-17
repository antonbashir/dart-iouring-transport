library iouring_transport;

import 'dart:async';
import 'dart:convert';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server\n");

  Transport(
    TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.error),
    TransportDefaults.acceptor(),
    TransportDefaults.channel(),
    TransportDefaults.connector(),
  ).run().then((loop) async {
    final clients = await loop.provider.connector.connect("127.0.0.1", 12345);
    loop.serve("0.0.0.0", 9000, onAccept: (channel, descriptor) => channel.read(descriptor)).listen((event) async {
      await clients.select().write(fromServer);
      event.respond(fromServer);
    });
  });

  await Future.delayed(Duration(days: 1));
}
