library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/server.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server");

  final transport = Transport()
    ..initialize(
      TransportDefaults.transport(),
      TransportDefaults.acceptor(),
      TransportDefaults.channel(),
      TransportDefaults.loop(),
    )
    ..listen(
      "0.0.0.0",
      9999,
      (port) => TransportServer(port).serve(
        onAccept: (channel, descriptor) => channel.read(descriptor),
        onInput: (payload, provider) => fromServer,
      ),
      isolates: Platform.numberOfProcessors,
    );

  await Future.delayed(Duration(days: 1));
}
