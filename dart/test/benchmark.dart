import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  //await _benchUnixStream();
  await _benchTcp();
  //await _benchFile();
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
      print("before start: ${ProcessInfo.currentRss}");
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (connection) => connection.listen((payload) => connection.writeSingle(payload.takeBytes())));
      final connector = await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: 256));
      var count = 0;
      final time = Stopwatch();
      time.start();
      print("after start: ${ProcessInfo.currentRss}");
      while (true) {
        count += (await Future.wait(connector.map((client) => client.writeSingle(fromServer).then((value) => client.read()).then((value) => value.release())))).length;
        if (time.elapsed.inHours >= 4) break;
      }
      print("after end: ${ProcessInfo.currentRss}");
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("RPS: ${count / 4 * 60 * 60}");
  await transport.shutdown();
}

Future<void> _benchUnixStream() async {
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
      print("before start: ${ProcessInfo.currentRss}");
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final worker = TransportWorker(input);
      await worker.initialize();
      final server = worker.servers.unixStream("benchmark-${worker.id}.sock", (connection) => connection.listen((payload) => payload.release()));
      final connector = await worker.clients.unixStream("benchmark-${worker.id}.sock", configuration: TransportDefaults.unixStreamClient().copyWith(pool: 256));
      var count = 0;
      final time = Stopwatch();
      time.start();
      print("after start: ${ProcessInfo.currentRss}");
      while (true) {
        final responses = await Future.wait(connector.map((client) => client.writeSingle(fromServer)).toList());
        count += responses.length;
        responses.clear();
        if (time.elapsed.inSeconds >= 30) break;
      }
      print("after end: ${ProcessInfo.currentRss}");
      await connector.close();
      await server.close();
      print("after close: ${ProcessInfo.currentRss}");
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("RPS: ${count / 30}");
  await transport.shutdown();
  await Future.delayed(Duration(seconds: 5));
  print("after shutdown: ${ProcessInfo.currentRss}");
}

Future<void> _benchFile() async {
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
      print("before start: ${ProcessInfo.currentRss}");
      final encoder = Utf8Encoder();
      final fromServer = encoder.convert("from server\n");
      final worker = TransportWorker(input);
      await worker.initialize();
      final file = worker.files.open("file", create: true, truncate: true);
      var count = 0;
      final time = Stopwatch();
      time.start();
      print("after start: ${ProcessInfo.currentRss}");
      final futures = <Future>[];
      while (true) {
        for (var i = 0; i < 10000; i++) {
          futures.add(file.writeSingle(fromServer));
          futures.add(file.readSingle().then((value) => value.release()));
        }
        count += (await Future.wait(futures)).length;
        if (time.elapsed.inSeconds >= 360) break;
      }
      await Future.delayed(Duration(seconds: 5));
      print("after end: ${ProcessInfo.currentRss}");
      worker.transmitter!.send(count);
    },
  );
  final count = await receiver.take(TransportDefaults.transport().workerInsolates).reduce((previous, element) => previous + element);
  print("RPS: ${count / 360}");
  await transport.shutdown();
}
