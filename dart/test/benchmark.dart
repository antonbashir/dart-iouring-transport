library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  await _benchTcp();
}

Future<void> _benchTcp() async {
  final ReceivePort receiver = ReceivePort();
  final transport = Transport(
    TransportDefaults.transport(),
    TransportDefaults.listener(),
    TransportDefaults.inbound(),
    TransportDefaults.outbound(),
  );
  transport.run(
    transmitter: receiver.sendPort,
    (input) async {
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.udp(InternetAddress("0.0.0.0"), 12345).listen((payload) => payload.respondSingleMessage(payload.takeBytes()));
      final connector = await worker.clients.udp(InternetAddress("127.0.0.1"), 12346, InternetAddress("127.0.0.1"), 12345);
      var count = 0;
      final time = Stopwatch();
      time.start();
      while (true) {
        count += connector.sendSingleMessage(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
        if (time.elapsed.inSeconds >= 60) break;
      }
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("RPS: ${count / 60}");
  await transport.shutdown();
}
