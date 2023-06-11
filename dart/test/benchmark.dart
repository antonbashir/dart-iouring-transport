import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  await _benchTcp();
}

Future<void> _benchTcp() async {
  final transport = Transport();
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server\n");

  for (var i = 0; i < 2; i++) {
    Isolate.spawn((SendPort message) async {
      final worker = TransportWorker(message);
      await worker.initialize();
      worker.servers.tcp(
        InternetAddress("0.0.0.0"),
        12345,
        (connection) => connection.stream().listen((payload) {
          payload.release();
          connection.writeSingle(fromServer);
        }),
      );
    }, transport.worker(TransportDefaults.worker().copyWith(ringFlags: ringSetupSqpoll)));
  }
  await Future.delayed(Duration(seconds: 1));
  for (var i = 0; i < 2; i++) {
    Isolate.spawn((SendPort message) async {
      final worker = TransportWorker(message);
      await worker.initialize();
      final connector = await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: 256));
      var count = 0;
      final time = Stopwatch();
      time.start();
      for (var client in connector.clients) {
        client.stream().listen((element) {
          count++;
          element.release();
          client.writeSingle(fromServer);
        });
        client.writeSingle(fromServer);
      }
      await Future.delayed(Duration(seconds: 10));
      print("RPS: ${count / 10}");
    }, transport.worker(TransportDefaults.worker()));
  }

  await Future.delayed(Duration(seconds: 15));
  await transport.shutdown();
}
