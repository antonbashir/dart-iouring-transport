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
  // await _benchFile(true);
  //await _benchFile(true);
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
      worker.servers.tcp("0.0.0.0", 12345, (connection) => connection.listen((payload) => connection.writeSingle(payload.takeBytes())));
      final connector = await worker.clients.tcp("127.0.0.1", 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: 256));
      var count = 0;
      final time = Stopwatch();
      time.start();
      while (true) {
        count += (await Future.wait(connector.map((client) => client.writeSingle(fromServer).then((value) => client.readSingle()).then((value) => value.release())))).length;
        if (time.elapsed.inSeconds >= 10) break;
      }
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("RPS: ${count / 10}");
  await transport.shutdown();
}

Future<void> _benchFile(bool ring) async {
  final ReceivePort receiver = ReceivePort();
  final file = File("data");
  if (!file.existsSync()) {
    file.createSync();
    final random = Random();
    final sink = file.openWrite(mode: FileMode.append);
    for (var i = 0; i < 1024; i++) {
      sink.add(List.filled(1024 * 1024, 100, growable: false));
      await sink.flush();
    }
    await sink.close();
    print("generated");
  }
  final transport = Transport(
    TransportDefaults.transport().copyWith(workerInsolates: 1),
    TransportDefaults.listener(),
    TransportDefaults.inbound(),
    TransportDefaults.outbound().copyWith(bufferSize: 64 * 1024, buffersCount: 2048),
  );
  transport.run(
    transmitter: receiver.sendPort,
    (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final file = worker.files.open("data");
      var count = 0;
      final time = Stopwatch();
      time.start();
      if (ring) {
        while (true) {
          print((await file.load()).length);
          count += 1;
          if (time.elapsed.inSeconds >= 10) break;
        }
      } else {
        while (true) {
          print((await File("data").readAsBytes()).length);
          count += 1;
          if (time.elapsed.inSeconds >= 10) break;
        }
      }
      worker.transmitter!.send(count);
      print("done");
    },
  );
  final count = await receiver.take(1).reduce((previous, element) => previous + element);
  print("RPS: ${count / 10}");
  await transport.shutdown();
}
