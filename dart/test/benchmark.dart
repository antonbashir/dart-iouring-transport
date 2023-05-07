library iouring_transport;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

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
      worker.servers.tcp(InternetAddress("0.0.0.0"), 2345, (connection) => connection.listen((payload) => connection.writeSingle(payload.takeBytes())));
      final connector = await worker.clients.tcp(InternetAddress("127.0.0.1"), 2345, configuration: TransportDefaults.tcpClient().copyWith(pool: 256));
      var count = 0;
      final time = Stopwatch();
      time.start();
      while (true) {
        count += (await Future.wait(connector.map((client) => client.writeSingle(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
        if (time.elapsed.inSeconds >= 30) break;
      }
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("RPS: ${count / 30}");
  await transport.shutdown();
}
