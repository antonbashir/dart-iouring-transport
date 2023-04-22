
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void testTcp({
  required int index,
  required int listeners,
  required int workers,
  required int clientsPool,
  required int listenerFlags,
  required int workerFlags,
  Duration? serverTimeout,
  Duration? clientTimeout,
}) {
  serverTimeout = serverTimeout ?? Duration(days: 1);
  clientTimeout = clientTimeout ?? Duration(seconds: 90);
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
      worker.servers.tcp(
          "0.0.0.0",
          12345,
          (communicator) => communicator.listen(
                onError: (error, _) => print(error),
                (event) => communicator.write(serverData).then((value) => worker.transmitter!.send(serverData)).onError((error, stackTrace) => print(error)),
              ));
      final clients = await worker.clients.tcp("127.0.0.1", 12345, configuration: TransportDefaults.tcpClient().copyWith(pool: clientsPool));
      final responses = await Future.wait(clients.map((client) => client.write(clientData).then((_) => client.read().then((value) => value.extract()))).toList());
      responses.forEach((response) => worker.transmitter!.send(response));
    });
    (await done.take(workers * clientsPool * 2).toList()).forEach((response) => expect(response, serverData));
    done.close();
    await transport.shutdown();
  });
}
