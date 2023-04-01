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
  // group("[tcp]", () {
  //   final echoTestsCount = 5;
  //   for (var index = 0; index < echoTestsCount; index++) {
  //     echoTcp(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoTcp(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoTcp(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoTcp(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoTcp(index: index, listeners: 2, workers: 2, clients: 8, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //   }
  // });
  // group("[unix stream]", () {
  //   final echoTestsCount = 5;
  //   for (var index = 0; index < echoTestsCount; index++) {
  //     echoUnixStream(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoUnixStream(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoUnixStream(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoUnixStream(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //     echoUnixStream(index: index, listeners: 2, workers: 2, clients: 8, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  //   }
  // });
  group("[unix dgram]", () {
    final echoTestsCount = 5;
    for (var index = 0; index < echoTestsCount; index++) {
      echoUnixDgram(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      echoUnixDgram(index: index, listeners: 2, workers: 2, clients: 8, listenerFlags: 0, workerFlags: ringSetupSqpoll);
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
      worker.serveTcp("0.0.0.0", 12345, (channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.connectTcp("127.0.0.1", 12345);
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read())).toList());
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
      worker.serveUnixStream(Directory.current.path + "/socket_${worker.id}.sock", (channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.connectUnix(Directory.current.path + "/socket_${worker.id}.sock");
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read())).toList());
      responses.forEach((response) => worker.transmitter!.send(response.bytes));
      responses.forEach((response) => response.release());
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
      for (var i = 0; i < clients; i++) {
        if (File(Directory.current.path + "/socket_${worker.id}_$i.sock").existsSync()) File(Directory.current.path + "/socket_${worker.id}_$i.sock").deleteSync();
      }
      worker.serveUnixDgram(Directory.current.path + "/socket_${worker.id}.sock", (channel) => channel.receiveMessage(), (stream) => stream.listen((event) => event.respond(serverData)));
      final responseFutures = <Future<TransportOutboundPayload>>[];
      for (var i = 0; i < clients; i++) {
        final client = worker.createUnixDgramClient(Directory.current.path + "/socket_${worker.id}_$i.sock", Directory.current.path + "/socket_${worker.id}.sock");
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
