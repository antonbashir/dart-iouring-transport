import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void main() {
  group("[tcp]", () {
    final testTestsCount = 5;
    for (var index = 0; index < testTestsCount; index++) {
      testTcp(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 4, workers: 4, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 4, workers: 4, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 2, workers: 2, clientsPool: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[unix stream]", () {
    final testTestsCount = 5;
    for (var index = 0; index < testTestsCount; index++) {
      testUnixStream(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 4, workers: 4, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 4, workers: 4, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 4, workers: 4, clientsPool: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[unix dgram]", () {
    final testTestsCount = 5;
    for (var index = 0; index < testTestsCount; index++) {
      testUnixDgram(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[udp]", () {
    final testTestsCount = 5;
    for (var index = 0; index < testTestsCount; index++) {
      testUdp(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[custom]", () => testCustomCallback());
}

void testTcp({
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
      worker.servers.tcp("0.0.0.0", 12345, (channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.clients.tcp("127.0.0.1", 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read().then((value) => value.extract()))).toList());
      responses.forEach((response) => worker.transmitter!.send(response));
    });
    (await done.take(workers * clientsPool).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}

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
      worker.servers.udp("0.0.0.0", 12345, (channel) => channel.receiveMessage(), (stream) => stream.listen((event) => event.respond(serverData)));
      final responseFutures = <Future<List<int>>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.udp("127.0.0.1", (worker.id + 1) * 2000 + (clientIndex + 1), "127.0.0.1", 12345);
        responseFutures.add(client.sendMessage(clientData).then((value) {
          return client.receiveMessage();
        }).then((value) {
          return value.extract();
        }));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach((response) => worker.transmitter!.send(response));
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}

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
      worker.servers.unixStream(serverSocket.path, (channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.clients.unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read().then((value) => value.extract()))).toList());
      responses.forEach((response) => worker.transmitter!.send(response));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
    });
    (await done.take(workers * clientsPool).toList()).forEach((response) => expect(response, serverData));
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
      worker.servers.unixDatagram(serverSocket.path, (channel) => channel.receiveMessage(), (stream) => stream.listen((event) => event.respond(serverData)));
      final responseFutures = <Future<List<int>>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.unixDatagram(clientSockets[clientIndex].path, serverSocket.path);
        responseFutures.add(client.sendMessage(clientData).then((value) => client.receiveMessage()).then((value) => value.extract()));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach((response) => worker.transmitter!.send(response));
      if (serverSocket.existsSync()) serverSocket.deleteSync();
      clientSockets.where((socket) => socket.existsSync()).forEach((socket) => socket.deleteSync());
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}

void testCustomCallback() {
  test("callback", () async {
    final transport = Transport(
      TransportDefaults.transport(),
      TransportDefaults.listener(),
      TransportDefaults.inbound(),
      TransportDefaults.outbound(),
    );
    final done = ReceivePort();
    final data = Random().nextInt(100);
    await transport.run(transmitter: done.sendPort, (input) async {
      final completer = Completer<int>();
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.registerCallback(1, completer);
      worker.notifyCustom(1, data);
      worker.transmitter!.send(await completer.future);
    });
    expect(await done.first, data);
    done.close();
    await transport.shutdown();
  });
}
