library iouring_transport;

import 'dart:async';
import 'dart:convert';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server\n");

  Transport(TransportDefaults.transport().copyWith(logLevel: TransportLogLevel.error), TransportDefaults.acceptor(), TransportDefaults.channel(), TransportDefaults.connector(),
          libraryPath: "/home/developer/native/libtransport.so")
      .run()
      .then((loop) async {
    final clients = await loop.provider.connector.connect("192.168.128.119", 12345, pool: 512);
    final stopwatch = Stopwatch();
    stopwatch.start();
    var counter = 0;
    final futures = <Future>[];
    while (stopwatch.elapsedMilliseconds < 10000) {
      futures.add(clients.select().write(fromServer));
      counter++;
    }
    await Future.wait(futures);
    print(counter / 10);
  });

  await Future.delayed(Duration(days: 1));
}
