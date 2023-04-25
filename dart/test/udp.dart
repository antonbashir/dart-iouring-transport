import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'test.dart';

void testUdp({
  required int index,
  required int listeners,
  required int workers,
  required int clients,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("[index = $index, listeners = $listeners, workers = $workers, clients = $clients]", () async {
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
      worker.servers.udp("0.0.0.0", 12345).listenBySingle(
            onError: (error, _) => print(error),
            (event) => check(event, clientData, () => event.respondSingleMessage(serverData).then((value) => worker.transmitter!.send(serverData)).onError((error, stackTrace) => print(error))),
          );
      final responseFutures = <Future<List<int>>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.udp("127.0.0.1", (worker.id + 1) * 2000 + (clientIndex + 1), "127.0.0.1", 12345);
        responseFutures.add(client.sendSingleMessage(clientData, retry: TransportDefaults.retry()).then((value) => client.receiveSingleMessage()).then((value) => value.takeBytes()));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach((response) => worker.transmitter!.send(response));
    });
    (await done.take(workers * clients * 2).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}
