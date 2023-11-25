import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'latch.dart';
import 'validators.dart';

void testUnixStreamSingle({required int index, required int clientsPool}) {
  test("(single) [clients = $clientsPool]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverSocket = File(Directory.systemTemp.path + "/dart-iouring-socket_${worker.id}.sock");
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixStream(
      serverSocket.path,
      (connection) => connection.stream().listen(
        (event) {
          Validators.request(event.takeBytes());
          connection.writeSingle(Generators.response());
        },
      ),
    );
    final latch = Latch(clientsPool);
    final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
    clients.forEach((client) {
      client.writeSingle(Generators.request());
      client.stream().listen((event) {
        Validators.response(event.takeBytes());
        latch.countDown();
      });
    });
    await latch.done();
    await transport.shutdown(gracefulTimeout: Duration(milliseconds: 100));
  });
}

void testUnixStreamMany({required int index, required int clientsPool, required int count}) {
  test("(many) [clients = $clientsPool, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverSocket = File(Directory.systemTemp.path + "/dart-iouring-socket_${worker.id}.sock");
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixStream(
      serverSocket.path,
      (connection) {
        final serverResults = BytesBuilder();
        connection.stream().listen(
          (event) {
            serverResults.add(event.takeBytes());
            if (serverResults.length == Generators.requestsSumOrdered(count).length) {
              Validators.requestsSumOrdered(serverResults.takeBytes(), count);
              connection.writeMany(Generators.responsesOrdered(count));
            }
          },
        );
      },
    );
    final latch = Latch(clientsPool);
    final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
    clients.forEach((client) async {
      final clientResults = BytesBuilder();
      client.stream().listen(
        (event) {
          clientResults.add(event.takeBytes());
          if (clientResults.length == Generators.responsesSumOrdered(count).length) {
            Validators.responsesSumOrdered(clientResults.takeBytes(), count);
            latch.countDown();
          }
        },
      );
      client.writeMany(Generators.requestsOrdered(count));
    });
    await latch.done();
    await transport.shutdown(gracefulTimeout: Duration(milliseconds: 100));
  });
}

void testUnixDgramSingle({required int index, required int clients}) {
  test("(single) [clients = $clients]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverSocket = File(Directory.systemTemp.path + "/dart-iouring-socket_${worker.id}.sock");
    final clientSockets = List.generate(clients, (index) => File(Directory.systemTemp.path + "/dart-iouring-socket_${worker.id}_$index.sock"));
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixDatagram(serverSocket.path).receive().listen((event) {
      Validators.request(event.takeBytes());
      event.respondSingle(Generators.response());
    });
    final latch = Latch(clients);
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
      final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
      client.stream().listen((value) {
        Validators.response(value.takeBytes());
        latch.countDown();
      });
      client.sendSingle(Generators.request());
    }
    await latch.done();
    await transport.shutdown(gracefulTimeout: Duration(milliseconds: 100));
  });
}

void testUnixDgramMany({required int index, required int clients, required int count}) {
  test("(many) [clients = $clients, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverRequests = BytesBuilder();
    final serverSocket = File(Directory.systemTemp.path + "/dart-iouring-socket_${worker.id}.sock");
    final clientSockets = List.generate(clients, (index) => File(Directory.systemTemp.path + "/dart-iouring-socket_${worker.id}_$index.sock"));
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixDatagram(serverSocket.path).receive().listen(
      (responder) {
        serverRequests.add(responder.takeBytes());
        if (serverRequests.length == Generators.requestsSumUnordered(count).length) {
          Validators.requestsSumUnordered(serverRequests.takeBytes(), count);
        }
        responder.respondMany(Generators.responsesUnordered(2));
      },
    );
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      final latch = Latch(1);
      if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
      final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
      final clientResults = BytesBuilder();
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
    await transport.shutdown(gracefulTimeout: Duration(milliseconds: 100));
  });
}
