import 'dart:io' as io;
import 'dart:typed_data';

import 'package:iouring_transport/iouring_transport.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'latch.dart';
import 'validators.dart';

void testUdpSingle({required int index, required int clients}) {
  test("(single) [clients = $clients]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345).receive().listen(
      (event) {
        Validators.request(event.takeBytes());
        event.respondSingle(Generators.response());
      },
    );
    final latch = Latch(clients);
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      final client = worker.clients.udp(io.InternetAddress("127.0.0.1"), (worker.id + 1) * 2000 + (clientIndex + 1), io.InternetAddress("127.0.0.1"), 12345);
      client.stream().listen((event) {
        Validators.response(event.takeBytes());
        latch.countDown();
      });
      client.sendSingle(Generators.request());
    }
    await latch.done();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUdpMany({required int index, required int clients, required int count}) {
  test("(many) [clients = $clients, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverRequests = BytesBuilder();
    worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345).receive().listen(
      (responder) {
        serverRequests.add(responder.takeBytes());
        if (serverRequests.length == Generators.requestsSumUnordered(count).length) {
          Validators.requestsSumUnordered(serverRequests.takeBytes(), count);
        }
        responder.respondMany(Generators.responsesUnordered(2));
      },
    );
    final clientResults = BytesBuilder();
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      final latch = Latch(1);
      final client = worker.clients.udp(io.InternetAddress("127.0.0.1"), (worker.id + 1) * 2000 + (clientIndex + 1), io.InternetAddress("127.0.0.1"), 12345);
      client.stream().listen((event) {
        clientResults.add(event.takeBytes());
        if (clientResults.length == Generators.responsesSumUnordered(count * 2).length) {
          Validators.responsesSumUnordered(clientResults.takeBytes(), count * 2);
          latch.countDown();
        }
      });
      client.sendMany(Generators.requestsUnordered(count));
      await latch.done();
    }
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
