library iouring_transport;

import 'dart:async';
import 'dart:convert';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';

Future<void> main(List<String> args) async {
  final encoder = Utf8Encoder();
  final fromServer = encoder.convert("from server");
  final transport = Transport();
  final acceptor = transport.acceptor(TransportDefaults.acceptor(), "0.0.0.0", 9999);
  final channel = transport.channel(TransportDefaults.channel());
  transport.initialize(TransportDefaults.transport(), acceptor, channel);
  transport.work(
    2,
    (port) => TransportWorker(port)
      ..start(onRead: (payload) async {
        payload.finalize();
        await payload.channel.write(fromServer, payload.fd);
      }),
  );
  await Future.delayed(Duration(days: 1));
}
