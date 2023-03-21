library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  final ReceivePort receiver = ReceivePort();
  Transport(
    TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.info),
    TransportDefaults.acceptor(),
    TransportDefaults.listener(),
    TransportDefaults.worker(),
    TransportDefaults.connector(),
  ).serve(
    receiver: receiver.sendPort,
    "0.0.0.0",
    9000,
    (input) async {
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final transport = Transport(
        TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.info),
        TransportDefaults.acceptor(),
        TransportDefaults.listener(),
        TransportDefaults.worker(),
        TransportDefaults.connector(),
      );
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.serve((channel) => channel.read()).listen((event) => event.respond(fromServer));
      await worker.awaitServer();
      transport.logger.info("Served");
      // final connector = await worker.connect("127.0.0.1", 12345, pool: 128);
      // transport.logger.info("Connected");
      // final time = Stopwatch();
      // time.start();
      var count = 0;
      var done = false;
      await Future.delayed(Duration(days: 10));
      // while (!done) {
      //   count += (await Future.wait(connector.map((client) => client.write(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
      // }
      worker.receiver!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("Done: ${count / 10}");
  exit(0);
}
