import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testTcpSingle({
  required int index,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("(single) [index = $index, workers = $workers, clients = $clientsPool]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(
        io.InternetAddress("0.0.0.0"),
        12345,
        (connection) => connection.listen(
          (event, _) {
            Validators.request(event.takeBytes());
            connection.writeSingle(Generators.response());
          },
        ),
      );
      final clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(
        clients.map((client) => client.writeSingle(Generators.request()).then((_) => client.read().then((value) => value.takeBytes()))).toList(),
      );
      responses.forEach(Validators.response);
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testTcpMany({
  required int index,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
  required int count,
}) {
  test("(many) [index = $index, workers = $workers, clients = $clientsPool, count = $count]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(
        io.InternetAddress("0.0.0.0"),
        12345,
        (connection) {
          final serverRequests = BytesBuilder();
          connection.listen(
            (event, _) {
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
      await Future.wait(clients.map(
        (client) async {
          final clientResults = BytesBuilder();
          final completer = Completer();
          client.writeMany(Generators.requestsOrdered(count)).then(
                (_) => client.read(
                  (event, _) {
                    clientResults.add(event.takeBytes());
                    if (clientResults.length == Generators.responsesSumOrdered(count).length) completer.complete();
                  },
                ),
              );
          return completer.future.then((value) => Validators.responsesSumOrdered(clientResults.takeBytes(), count));
        },
      ));
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
