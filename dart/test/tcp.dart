import 'dart:async';
import 'dart:convert';
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
  test("[index = $index, listeners = $listeners, workers = $workers, clients = $clientsPool]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(listenerIsolates: listeners, workerInsolates: workers),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.run(transmitter: done.sendPort, (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(
        "0.0.0.0",
        12345,
        (connection) => connection.listenBySingle(
          onError: (error) => print(error),
          (event) {
            event.release();
            connection.writeSingle(serverData).onError((error, stackTrace) => print(error));
          },
        ),
      );
      final clients = await worker.clients.tcp("127.0.0.1", 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(clients.map((client) => client.writeSingle(clientData).then((_) => client.readSingle().then((value) => value.takeBytes()))).toList());
      responses.forEach((response) => worker.transmitter!.send(response));
    });
    (await done.take(workers * clientsPool).toList()).forEach((response) => expect(response, serverData));
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
  test("[index = $index, listeners = $listeners, workers = $workers, clients = $clientsPool]", () async {
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
          connection.listenBySingle(
            onError: (error) => print(error),
            (event) {
              serverResults.add(event.takeBytes());
              if (serverResults.length == Generators.requestsSum(count).length) {
                Validators.requestsSum(serverResults.takeBytes(), count);
                connection.writeMany(Generators.responses(count)).onError((error, stackTrace) => print(error));
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
                (_) => client.listenBySingle(
                  onError: (error) => print(error),
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
