import 'dart:io';

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
    final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixStream(
      serverSocket.path,
      (connection) => connection.read().listen(
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
      client.read().listen((event) {
        Validators.response(event.takeBytes());
        latch.countDown();
      });
    });
    await latch.done();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUnixStreamMany({required int index, required int clientsPool, required int count}) {
  test("(many) [clients = $clientsPool, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixStream(
      serverSocket.path,
      (connection) {
        final serverResults = BytesBuilder();
        connection.read().listen(
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
      client.read().listen(
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
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUnixDgramSingle({required int index, required int clients}) {
  test("(single) [clients = $clients]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
    final clientSockets = List.generate(clients, (index) => File(Directory.current.path + "/socket_${worker.id}_$index.sock"));
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixDatagram(serverSocket.path).receive().listen((event) {
      Validators.request(event.takeBytes());
      event.respond(Generators.response(), retry: TransportDefaults.retry());
    });
    final latch = Latch(clients);
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
      final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
      client.receive().listen((value) {
        Validators.response(value.takeBytes());
        latch.countDown();
      });
      client.send(Generators.request(), retry: TransportDefaults.retry());
    }
    await latch.done();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
