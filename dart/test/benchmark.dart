library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server\n");
  final transport = Transport(
    TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.info),
    TransportDefaults.acceptor(),
    TransportDefaults.channel(),
    TransportDefaults.connector(),
  );
  final loop = await transport.run();
  loop.serve("0.0.0.0", 12345, onAccept: (channel) => channel.read()).listen(
        (event) => event.respond(fromServer),
      );
  await loop.awaitServer();
  transport.logger.info("Served");
  final connector = await loop.connect("127.0.0.1", 12345, pool: 1000);
  transport.logger.info("Connected");
  final time = Stopwatch();
  time.start();
  var done = false;
  var count = 0;
  Timer.run(() async {
    while (!done) {
      count += (await Future.wait(connector.map((client) => client.write(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
    }
  });
  await Future.delayed(Duration(seconds: 10));
  done = true;
  print("Done ${count / time.elapsed.inSeconds}");
  exit(0);
}
