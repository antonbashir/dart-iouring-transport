library iouring_transport;

import 'dart:async';
import 'dart:convert';

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
  loop.serve("0.0.0.0", 12345, onAccept: (channel, descriptor) => channel.read(descriptor)).listen((event) => event.respond(fromServer));
  await loop.awaitServer();
  transport.logger.info("Served");
  await Future.delayed(Duration(seconds: 1));
  final connector = await loop.provider.connector.connect("127.0.0.1", 12345);
  transport.logger.info("Connected");
  var counter = 0;
  final stopwatch = Stopwatch();
  stopwatch.start();
  Timer.periodic(Duration(seconds: 1), (timer) {
    print(counter);
  });
  final client = connector.select();
  final futures = <Future>[];
  while (stopwatch.elapsedMilliseconds < 10000) {
    await client.write(fromServer);
    counter++;
  }
  print(counter / 10);

  await Future.delayed(Duration(days: 1));
}
