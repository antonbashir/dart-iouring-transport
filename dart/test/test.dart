import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/payload.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void main() {
  group("[tcp]", () {
    final echoTestsCount = 5;
    for (var index = 0; index < echoTestsCount; index++) {
      echoTcp(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoTcp(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoTcp(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoTcp(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoTcp(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[unix stream]", () {
    final echoTestsCount = 5;
    for (var index = 0; index < echoTestsCount; index++) {
      echoUnixStream(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixStream(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixStream(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixStream(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixStream(index: index, listeners: 4, workers: 4, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[unix dgram]", () {
    final echoTestsCount = 5;
    for (var index = 0; index < echoTestsCount; index++) {
      echoUnixDgram(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[udp]", () {
    final echoTestsCount = 5;
    for (var index = 0; index < echoTestsCount; index++) {
      echoUdp(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUdp(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUdp(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUdp(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUdp(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
}

void echoTcp({
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
      TransportDefaults.server(),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.client().copyWith(defaultPool: clients),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.run(transmitter: done.sendPort, (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.tcp("0.0.0.0", 12345, (channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.clients.tcp("127.0.0.1", 12345);
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read())).toList());
      responses.forEach((response) => worker.transmitter!.send(response.bytes));
      responses.forEach((response) => response.release());
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(serverData, response));
    done.close();
    await transport.shutdown();
  });
}

void echoUdp({
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
      TransportDefaults.server(),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.client(),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.run(transmitter: done.sendPort, (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.servers.udp("0.0.0.0", 12345, (channel) => channel.receiveMessage(), (stream) => stream.listen((event) => event.respond(serverData)));
      final responseFutures = <Future<TransportOutboundPayload>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.udp("127.0.0.1", (worker.id + 1) * 2000 + (clientIndex + 1), "127.0.0.1", 12345);
        responseFutures.add(client.sendMessage(clientData).then((value) => client.receiveMessage()));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach((response) => worker.transmitter!.send(response.bytes));
      responses.forEach((response) => response.release());
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(serverData, response));
    done.close();
    await transport.shutdown();
  });
}

void echoUnixStream({
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
      TransportDefaults.server(),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.client().copyWith(defaultPool: clients),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.run(transmitter: done.sendPort, (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      if (File(Directory.current.path + "/socket_${worker.id}.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}.sock").deleteSync();
      worker.servers.unixStream(Directory.current.path + "/socket_${worker.id}.sock", (channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.clients.unixStream(Directory.current.path + "/socket_${worker.id}.sock");
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read())).toList());
      responses.forEach((response) => worker.transmitter!.send(response.bytes));
      responses.forEach((response) => response.release());
      if (File(Directory.current.path + "/socket_${worker.id}.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}.sock").deleteSync();
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(serverData, response));
    done.close();
    await transport.shutdown();
  });
}

void echoUnixDgram({
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
      TransportDefaults.server(),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.client(),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.run(transmitter: done.sendPort, (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      if (File(Directory.current.path + "/socket_${worker.id}.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}.sock").deleteSync();
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        if (File(Directory.current.path + "/socket_${worker.id}_$clientIndex.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}_$clientIndex.sock").deleteSync();
      }
      worker.servers.unixDatagram(Directory.current.path + "/socket_${worker.id}.sock", (channel) => channel.receiveMessage(), (stream) => stream.listen((event) => event.respond(serverData)));
      final responseFutures = <Future<TransportOutboundPayload>>[];
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        final client = worker.clients.unixDatagram(Directory.current.path + "/socket_${worker.id}_$clientIndex.sock", Directory.current.path + "/socket_${worker.id}.sock");
        responseFutures.add(client.sendMessage(clientData).then((value) => client.receiveMessage()));
      }
      final responses = await Future.wait(responseFutures);
      responses.forEach((response) => worker.transmitter!.send(response.bytes));
      responses.forEach((response) => response.release());
      if (File(Directory.current.path + "/socket_${worker.id}.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}.sock").deleteSync();
      for (var clientIndex = 0; clientIndex < clients; clientIndex++) {
        if (File(Directory.current.path + "/socket_${worker.id}_$clientIndex.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}_$clientIndex.sock").deleteSync();
      }
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(serverData, response));
    done.close();
    await transport.shutdown();
  });
}
