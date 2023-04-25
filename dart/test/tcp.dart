import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'test.dart';

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
          onError: (error, _) => print(error),
          (event) => check(event.takeBytes(), clientData, () => connection.writeSingle(serverData).onError((error, stackTrace) => print(error))),
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
    final clientRequests = List.generate(count, (index) => Utf8Encoder().convert("request-$index")).reduce((value, element) => Uint8List.fromList(value + element));
    final serverResponses = List.generate(count, (index) => Utf8Encoder().convert("respond-$index"));
    await transport.run(transmitter: done.sendPort, (input) async {
      final serverResults = BytesBuilder();
      final clientResults = <Uint8List>[];
      final clientRequests = List.generate(count, (index) => Utf8Encoder().convert("request-$index"));
      final serverResponses = List.generate(count, (index) => Utf8Encoder().convert("respond-$index"));
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp(
        "0.0.0.0",
        12345,
        (connection) => connection.listenBySingle(
          onError: (error, _) => print(error),
          (event) {
            serverResults.add(event.takeBytes());
            connection.writeMany(serverResponses).onError((error, stackTrace) => print(error));
          },
        ),
      );
      final clients = await worker.clients.tcp(
        "127.0.0.1",
        12345,
        configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool),
      );
      await Future.wait(clients
          .map((client) => client.writeMany(clientRequests).then((_) => client.readMany(count)).then((responses) => responses.map((element) => element.takeBytes())))
          .map((responses) => responses.then(clientResults.addAll)));
      worker.transmitter!.send([serverResults.takeBytes(), clientResults]);
    });
    (await done.take(workers).toList()).forEach((result) {
      expect(result[0], clientRequests);
      expect(result[1].map(Uint8List.fromList).toList(), serverResponses);
    });
    done.close();
    await transport.shutdown();
  });
}
