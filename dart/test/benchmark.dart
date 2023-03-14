library iouring_transport;

import 'dart:async';
import 'dart:convert';

import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/loop.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server");

  final transport = Transport()
    ..initialize(
      TransportDefaults.transport(),
      TransportDefaults.acceptor(),
      TransportDefaults.channel(),
    )
    ..listen(
      "0.0.0.0",
      9999,
      (port) {
        late TransportClient client;
        TransportEventLoop(port).run(
          onRun: (provider) async {
            client = await provider.connector.connect("127.0.0.1", 12345);
          },
          onAccept: (channel, descriptor) => channel.read(descriptor),
          onInput: (payload) {
            client.write(fromServer);
            return fromServer;
          },
        );
      },
      isolates: 4,
    );

  await Future.delayed(Duration(days: 1));
}
