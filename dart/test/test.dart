import 'dart:convert';
import 'dart:isolate';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/model.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void main() {
  group("[base]", () {
    final echoTestsCount = 100;
    for (var index = 0; index < echoTestsCount; index++) {
      //echo(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
       echo(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      // echo(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      // echo(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      // echo(index: index, listeners: 2, workers: 2, clients: 8, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
}

void echo({
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
      TransportDefaults.acceptor(),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.client().copyWith(defaultPool: clients),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.serve(transmitter: done.sendPort, TransportUri.tcp("127.0.0.1", 12345), (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      await worker.serve((channel) => channel.read(), (stream) => stream.listen((event) => event.respond(serverData)));
      final clients = await worker.connect(TransportUri.tcp("127.0.0.1", 12345));
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read())).toList());
      responses.forEach((response) => worker.transmitter!.send(response.bytes));
      responses.forEach((response) => response.release());
    });
    (await done.take(workers * clients).toList()).forEach((response) => expect(serverData, response));
    done.close();
    await transport.shutdown();
  });
}
