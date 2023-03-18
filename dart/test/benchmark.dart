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
  loop.serve("0.0.0.0", 12345, onAccept: (channel, descriptor) => channel.read(descriptor)).listen(
        (event) => event.respond(fromServer),
      );
  transport.logger.info("Served");
  final connector = await loop.connect("127.0.0.1", 12345);
  final client = connector.select();
  transport.logger.info("Connected");
  final time = Stopwatch();
  final futures = <Future>[];
  time.start();
  for (var i = 0; i < 100000; i++) {
    futures.add(client.write(fromServer).then((value) => client.read()).then((value) => value.release()));
  }
  await Future.wait(futures);
  print("Done ${futures.length / time.elapsed.inSeconds}");
  await Future.delayed(Duration(days: 1));
}
