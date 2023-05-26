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

void testTcpSingle({required int index, required int clientsPool}) {
  test("(single) [clients = $clientsPool]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    worker.servers.tcp(
      io.InternetAddress("0.0.0.0"),
      12345,
      (connection) => connection.read().listen(
        (event) {
          Validators.request(event.takeBytes());
          connection.writeSingle(Generators.response());
        },
      ),
    );
    final clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool));
    final latch = Latch(clientsPool);
    clients.forEach((client) {
      client.writeSingle(Generators.request());
      client.read().listen((value) {
        Validators.response(value.takeBytes());
        latch.countDown();
      });
    });
    await latch.done();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testTcpMany({required int index, required int clientsPool, required int count}) {
  test("(many) [clients = $clientsPool, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    worker.servers.tcp(
      io.InternetAddress("0.0.0.0"),
      12345,
      (connection) {
        final serverRequests = BytesBuilder();
        connection.read().listen(
          (event) {
            serverRequests.add(event.takeBytes());
            if (serverRequests.length == Generators.requestsSumOrdered(count).length) {
              Validators.requestsSumOrdered(serverRequests.takeBytes(), count);
              connection.writeMany(Generators.responsesOrdered(count));
            }
          },
        );
      },
    );
    final clients = await worker.clients.tcp(
      io.InternetAddress("127.0.0.1"),
      12345,
      configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool),
    );
    final clientResults = BytesBuilder();
    final latch = Latch(clientsPool);
    clients.forEach((client) {
      client.writeMany(Generators.requestsOrdered(count));
      client.read().listen(
        (event) {
          clientResults.add(event.takeBytes());
          if (clientResults.length == Generators.responsesSumOrdered(count).length) {
            Validators.responsesSumOrdered(clientResults.takeBytes(), count);
            latch.countDown();
          }
        },
      );
    });
    await latch.done();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
