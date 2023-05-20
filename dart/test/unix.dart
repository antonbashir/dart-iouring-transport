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

void testUnixStreamSingle({
  required int index,
  required int listeners,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("(single) [index = $index, workers = $workers, clients = $clientsPool]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      worker.servers.unixStream(
        serverSocket.path,
        (connection) => connection.listen(
          (event, _) {
            Validators.request(event.takeBytes());
            connection.writeSingle(Generators.response());
          },
        ),
      );
      final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
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

void testUnixStreamMany({
  required int index,
  required int listeners,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
  required int count,
}) {
  test("(many) [index = $index, workers = $workers, clients = $clientsPool, count = $count]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      worker.servers.unixStream(
        serverSocket.path,
        (connection) {
          final serverResults = BytesBuilder();
          connection.listen(
            (event, _) {
              serverResults.add(event.takeBytes());
              if (serverResults.length == Generators.requestsSumOrdered(count).length) {
                Validators.requestsSumOrdered(serverResults.takeBytes(), count);
                connection.writeMany(Generators.responsesOrdered(count));
              }
            },
          );
        },
      );
      final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
      await Future.wait(clients.map(
        (client) async {
          final clientResults = BytesBuilder();
          final completer = Completer();
          client.writeMany(Generators.requestsOrdered(count)).then(
                (_) => client.listen(
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

void testUnixDgramSingle({
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
      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      final clientSockets = List.generate(clients, (index) => File(Directory.current.path + "/socket_${worker.id}_$index.sock"));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      worker.servers.unixDatagram(serverSocket.path).listen((event, _) {
        event.respondSingleMessage(Generators.response(), retry: TransportDefaults.retry()).then((value) {
          Validators.request(event.takeBytes());
        });
      });
      final responseFutures = <Future<Uint8List>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
        final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
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

void testUnixDgramMany({
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
      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      final clientSockets = List.generate(clients, (index) => File(Directory.current.path + "/socket_${worker.id}_$index.sock"));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      worker.servers.unixDatagram(serverSocket.path).listen((event, _) {
        event.respondManyMessage(Generators.responsesUnordered(count), retry: TransportDefaults.retry()).then((value) => Validators.request(event.takeBytes()));
      });
      final responsesSumLength = Generators.responsesSumUnordered(count * count).length;
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
        final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
        final clientResults = BytesBuilder();
        final completer = Completer();
        client.sendManyMessages(Generators.requestsUnordered(count), retry: TransportDefaults.retry()).then(
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
