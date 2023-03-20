library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  Transport(
    TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.info),
    TransportDefaults.acceptor(),
    TransportDefaults.channel(),
    TransportDefaults.connector(),
  ).serve(
    "0.0.0.0",
    12345,
    (input) async {
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final transport = Transport(
        TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.info),
        TransportDefaults.acceptor(),
        TransportDefaults.channel(),
        TransportDefaults.connector(),
      );
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.serve((channel) => channel.read()).listen((event) => event.respond(fromServer));
      await worker.awaitServer();
      transport.logger.info("Served");
      final connector = await worker.connect("127.0.0.1", 12345, pool: 1000);
      transport.logger.info("Connected");
      final time = Stopwatch();
      time.start();
      var count = 0;
      Timer.periodic(Duration.zero, (_) async {
        count += (await Future.wait(connector.map((client) => client.write(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
      });
      print("Done ${count / time.elapsed.inSeconds}");
    },
  );
  await Future.delayed(Duration(seconds: 10));
  await Future.delayed(Duration(seconds: 1));
  exit(0);
}
