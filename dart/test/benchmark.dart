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
    ..listen().then(
      (loop) async {
        final client = await loop.provider.connector.connect("35.202.158.55", 12345);
        loop.serve(
          "0.0.0.0",
          9999,
          onAccept: (channel, descriptor) => channel.read(descriptor),
          onInput: (payload) async {
            client.write(fromServer);
            return fromServer;
          },
        );
      },
    );

  await Future.delayed(Duration(days: 1));
}
