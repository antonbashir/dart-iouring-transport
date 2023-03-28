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
        await worker.serve(
            (channel) => channel.read(),
            (stream) => stream.listen(
                  (event) {
                    print("Received request");
                    event.respond(serverData);
                  },
                ));
        print("Served");
        final client = await worker.connect(TransportUri.tcp("127.0.0.1", 12345));
        print("Connected");
        await client.select().write(clientData);
        print("Sent request");
        final response = await client.select().read();
        print("Received response");
        expect(response.bytes, serverData);
        response.release();
        exit(0);
      });
    });
  });
}
