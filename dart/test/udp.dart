import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testUdpSingle({
  required int index,
  required int listeners,
  required int workers,
  required int clients,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("(single) [index = $index, workers = $workers, clients = $clients]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.udp(InternetAddress("0.0.0.0"), 12345).listen(
        (event, _) {
          event.respondSingleMessage(Generators.response()).then((value) {
            Validators.request(event.takeBytes());
          });
        },
      );
      final responseFutures = <Future<Uint8List>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.udp(InternetAddress("127.0.0.1"), (worker.id + 1) * 2000 + (clientIndex + 1), InternetAddress("127.0.0.1"), 12345);
        responseFutures.add(client.sendSingleMessage(Generators.request(), retry: TransportDefaults.retry()).then((value) => client.receiveSingleMessage()).then((value) => value.takeBytes()));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach(Validators.response);
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUdpMany({
  required int index,
  required int listeners,
  required int workers,
  required int clients,
  required int listenerFlags,
  required int workerFlags,
  required int count,
}) {
  test("(many) [index = $index, workers = $workers, clients = $clients, count = $count]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.udp(InternetAddress("0.0.0.0"), 12345).listen((event, _) {
        event.respondManyMessage(Generators.responsesUnordered(count)).then((value) => Validators.request(event.takeBytes()));
      });
      final responsesSumLength = Generators.responsesSumUnordered(count * count).length;
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.udp(InternetAddress("127.0.0.1"), (worker.id + 1) * 2000 + (clientIndex + 1), InternetAddress("127.0.0.1"), 12345);
        final clientResults = BytesBuilder();
        final completer = Completer();
        client.sendManyMessages(Generators.requestsUnordered(count)).then(
              (_) => client.listenByMany(
                count,
                (event, _) {
                  clientResults.add(event.takeBytes());
                  if (clientResults.length == responsesSumLength) completer.complete();
                },
              ),
            );
        await completer.future.then((_) => Validators.responsesUnorderedSum(clientResults.takeBytes(), count * count));
      }
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
