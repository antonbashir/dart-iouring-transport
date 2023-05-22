import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';

void testShutdown({required Duration gracefulDuration}) {
  test("[gracefulDuration = ${gracefulDuration.inSeconds}]", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.worker(), TransportDefaults.outbound());
    final done = ReceivePort();
    transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final file = File("file");
      if (file.existsSync()) file.deleteSync();

      final serverCompleter = Completer();
      final fileCompleter = Completer();
      final clientCompleter = Completer();
      final server = worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (connection) => connection.writeSingle(Generators.request()).then((value) => serverCompleter.complete()));
      final clients = await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345);

      var fileProvider = worker.files.open(file.path, create: true);
      fileProvider.writeSingle(Generators.request());

      fileProvider.readSingle().then((value) {
        value.release();
        fileCompleter.complete();
      });
      clients.select().read().then((value) {
        value.release();
        clientCompleter.complete();
      });

      await serverCompleter.future;
      final futures = [
        server.close(gracefulDuration: gracefulDuration),
        clients.close(gracefulDuration: gracefulDuration),
        fileProvider.close(gracefulDuration: gracefulDuration),
      ];
      await Future.wait(futures);
      await fileCompleter.future;
      await clientCompleter.future;

      if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");
      if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
      if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
      if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");
      if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

      if (file.existsSync()) file.deleteSync();

      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown();
  });
}
