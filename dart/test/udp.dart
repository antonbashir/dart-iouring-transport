import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

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
    worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345).receiveBySingle().listen(
      (event) {
        Validators.request(event.takeBytes());
        event.respondSingleMessage(Generators.response());
      },
    );
    final latch = Latch(clients);
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      final client = worker.clients.udp(io.InternetAddress("127.0.0.1"), (worker.id + 1) * 2000 + (clientIndex + 1), io.InternetAddress("127.0.0.1"), 12345);
      client.receiveBySingle().listen((event) {
        Validators.response(event.takeBytes());
        latch.countDown();
      });
      client.sendSingleMessage(Generators.request(), retry: TransportDefaults.retry());
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
    worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345).receiveByMany(count).listen((event) {
      Validators.request(event.takeBytes());
      event.respondManyMessages(Generators.responsesUnordered(count));
    });
    final responsesSumLength = Generators.responsesSumUnordered(count * count).length;
    final latch = Latch(clients);
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      final client = worker.clients.udp(io.InternetAddress("127.0.0.1"), (worker.id + 1) * 2000 + (clientIndex + 1), io.InternetAddress("127.0.0.1"), 12345);
      final clientResults = BytesBuilder();
      client.receiveByMany(count).listen(
        (event) {
          clientResults.add(event.takeBytes());
          if (clientResults.length == responsesSumLength) {
            Validators.responsesUnorderedSum(clientResults.takeBytes(), count * count);
            latch.countDown();
          }
        },
      );
      client.sendManyMessages(Generators.requestsUnordered(count));
    }
    await latch.done();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
