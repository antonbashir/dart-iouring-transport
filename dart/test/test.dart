import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/model.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void main() {
  group("[base]", () {
    echo(1, 1, 1);
    echo(2, 2, 1);
    echo(4, 4, 1);
    echo(4, 4, 128);
  });
}

void echo(int listeners, int workers, int clients) {
  test("[listeners = $listeners, workers = $workers, clients = $clients]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(listenerIsolates: listeners, workerInsolates: workers),
      TransportDefaults.acceptor(),
      TransportDefaults.listener(),
      TransportDefaults.worker(),
      TransportDefaults.client().copyWith(defaultPool: clients),
    );
    final done = ReceivePort();
    final serverData = Utf8Encoder().convert("respond");
    await transport.serve(transmitter: done.sendPort, TransportUri.tcp("127.0.0.1", 12345), (input) async {
      final clientData = Utf8Encoder().convert("request");
      final serverData = Utf8Encoder().convert("respond");
      final worker = TransportWorker(input);
      await worker.initialize();
      await worker.serve(
          (channel) => channel.read(),
          (stream) => stream.listen(
                (event) {
                  print("Received request");
                  event.respond(serverData);
                },
              ));
      print("Served");
      final client = await worker.connect(TransportUri.tcp("127.0.0.1", 12345));
      print("Connected");
      await client.select().write(clientData);
      print("Sent request");
      final response = await client.select().read();
      print("Received response");
      worker.transmitter!.send(response.bytes);
      response.release();
    });
    expect(serverData, await done.first);
    done.close();
    await transport.shutdown();
  });
}
