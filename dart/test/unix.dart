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
    final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
    clients.forEach((client) {
      client.writeSingle(Generators.request());
      client.read().listen((event) => Validators.response(event.takeBytes()));
    });
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
    final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
    clients.forEach((client) async {
      final clientResults = BytesBuilder();
      final completer = Completer();
      client.read().listen(
        (event) {
          clientResults.add(event.takeBytes());
          if (clientResults.length == Generators.responsesSumOrdered(count).length) completer.complete();
        },
      );
      client.writeMany(Generators.requestsOrdered(count));
      await completer.future.then((value) => Validators.responsesSumOrdered(clientResults.takeBytes(), count));
    });
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
    worker.servers.unixDatagram(serverSocket.path).receiveBySingle().listen((event) {
      Validators.request(event.takeBytes());
      event.respondSingleMessage(Generators.response(), retry: TransportDefaults.retry());
    });
    final responseFutures = <Future<Uint8List>>[];
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
      final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
      client.receiveBySingle().listen((value) => value.takeBytes());
      client.sendSingleMessage(Generators.request(), retry: TransportDefaults.retry());
    }
    final responses = await Future.wait(responseFutures);
    responses.forEach(Validators.response);
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUnixDgramMany({required int index, required int clients, required int count}) {
  test("(many) [clients = $clients, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
    final clientSockets = List.generate(clients, (index) => File(Directory.current.path + "/socket_${worker.id}_$index.sock"));
    if (serverSocket.existsSync()) serverSocket.deleteSync();
    worker.servers.unixDatagram(serverSocket.path).receiveByMany(count).listen((event) {
      Validators.request(event.takeBytes());
      event.respondManyMessage(Generators.responsesUnordered(count), retry: TransportDefaults.retry());
    });
    final responsesSumLength = Generators.responsesSumUnordered(count * count).length;
    for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
      if (clientSockets[clientIndex].existsSync()) clientSockets[clientIndex].deleteSync();
      final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
      final clientResults = BytesBuilder();
      final completer = Completer();
      client.receiveByMany(count).listen(
        (event) {
          clientResults.add(event.takeBytes());
          if (clientResults.length == responsesSumLength) completer.complete();
        },
      );
      client.sendManyMessages(Generators.requestsUnordered(count), retry: TransportDefaults.retry());
      await completer.future.then((_) => Validators.responsesUnorderedSum(clientResults.takeBytes(), count * count));
    }
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
