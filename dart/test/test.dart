import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/model.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

final Transport _transport = Transport(
  TransportDefaults.transport(),
  TransportDefaults.acceptor(),
  TransportDefaults.listener(),
  TransportDefaults.worker(),
  TransportDefaults.client(),
);

void main() {
  group("[base]", () {
    test("[echo]", () async {
      await _transport.serve(TransportUri.tcp("127.0.0.1", 12345), (input) async {
        final clientData = Utf8Encoder().convert("request");
        final serverData = Utf8Encoder().convert("respond");
        final worker = TransportWorker(input);
        await worker.initialize();
        await worker.serve((channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
        final client = await worker.connect(TransportUri.tcp("127.0.0.1", 12345));
        final response = await client.select().write(clientData).then((value) => client.select().read());
        expect(response.bytes, serverData);
        response.release();
        exit(0);
      });
    });
  });
}
