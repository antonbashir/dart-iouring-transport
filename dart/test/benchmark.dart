library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/model.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  final ReceivePort receiver = ReceivePort();
  Transport(
    TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.info),
    TransportDefaults.acceptor(),
    TransportDefaults.listener(),
    TransportDefaults.worker(),
    TransportDefaults.client(),
  ).serve(
    transmitter: receiver.sendPort,
    TransportUri.tcp("0.0.0.0", 12345),
    (input) async {
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final worker = TransportWorker(input);
      await worker.initialize();
      await worker.serve((channel) => channel.read(), (stream) => stream.listen((event) => event.respond(fromServer)));
      print("Served");
      final connector = await worker.connect(TransportUri.tcp("127.0.0.1", 12345), pool: 256);
      print("Connected");
      var count = 0;
      final time = Stopwatch();
      time.start();
      while (true) {
        count += (await Future.wait(connector.map((client) => client.write(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
        if (time.elapsed.inSeconds >= 10) break;
      }
      print("Send $count");
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("Done: ${count / 10}");
  exit(0);
}
