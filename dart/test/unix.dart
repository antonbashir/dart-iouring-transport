
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void testUnixStream({
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
      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      worker.servers.unixStream(
        serverSocket.path,
        (connection) => connection.listen(
          onError: (error, _) => print(error),
          (event) => connection.write(serverData).then((value) => worker.transmitter!.send(serverData)).onError((error, stackTrace) => print(error)),
        ),
      );
      final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read().then((value) => value.extract()))).toList());
      responses.forEach((response) => worker.transmitter!.send(response));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
    });
    (await done.take(workers * clientsPool * 2).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}

void testUnixDgram({
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
      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      final clientSockets = List.generate(clients, (index) => File(Directory.current.path + "/socket_${worker.id}_$index.sock"));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      clientSockets.where((socket) => socket.existsSync()).forEach((socket) => socket.deleteSync());
      worker.servers.unixDatagram(serverSocket.path).listen(
            onError: (error, _) => print(error),
            (event) => event.respondMessage(serverData).then((value) => worker.transmitter!.send(serverData)).onError((error, stackTrace) => print(error)),
          );
      final responseFutures = <Future<List<int>>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
        responseFutures.add(client.sendMessage(clientData, retry: TransportDefaults.retry()).then((value) => client.receiveMessage()).then((value) => value.extract()));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach((response) => worker.transmitter!.send(response));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      clientSockets.where((socket) => socket.existsSync()).forEach((socket) => socket.deleteSync());
    });
    (await done.take(workers * clients * 2).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}
