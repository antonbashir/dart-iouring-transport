import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'test.dart';
import 'validators.dart';

void testSingleTcp({
  required int index,
  required int listeners,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("(single) [index = $index, listeners = $listeners, workers = $workers, clients = $clientsPool]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(listenerIsolates: listeners, workerInsolates: workers),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(
        "0.0.0.0",
        12345,
        (connection) => connection.listen(
          onError: print,
          (event) {
            Validators.request(event.takeBytes());
            connection.writeSingle(Generators.response()).onError(errorPrinter);
          },
        ),
      );
      final clients = await worker.clients.tcp("127.0.0.1", 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(
        clients.map((client) => client.writeSingle(Generators.request()).then((_) => client.read().then((value) => value.takeBytes()))).toList(),
      );
      responses.forEach((response) => Validators.response(response));
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown();
  });
}

void testManyTcp({
  required int index,
  required int listeners,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
  required int count,
}) {
  test("(many) [index = $index, listeners = $listeners, workers = $workers, clients = $clientsPool]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(listenerIsolates: listeners, workerInsolates: workers),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(
        "0.0.0.0",
        12345,
        (connection) {
          final serverResults = BytesBuilder();
          connection.listen(
            onError: print,
            (event) {
              serverResults.add(event.takeBytes());
              if (serverResults.length == Generators.requestsSum(count).length) {
                Validators.requestsSum(serverResults.takeBytes(), count);
                connection.writeMany(Generators.responses(count)).onError(errorPrinter);
              }
            },
          );
        },
      );
      final clients = await worker.clients.tcp(
        "127.0.0.1",
        12345,
        configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool),
      );
      await Future.wait(clients.map(
        (client) async {
          final clientResults = BytesBuilder();
          final completer = Completer();
          client.writeMany(Generators.requests(count)).then(
                (_) => client.listen(
                  onError: print,
                  (event) {
                    clientResults.add(event.takeBytes());
                    if (clientResults.length == Generators.responsesSum(count).length) completer.complete();
                  },
                ),
              );
          return completer.future.then((value) => Validators.responsesSum(clientResults.takeBytes(), count));
        },
      ));
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown();
  });
}
