import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testBulk() {
  test("bulk", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.listener(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final file1 = File("file1");
      final file2 = File("file2");
      final file3 = File("file3");
      if (file1.existsSync()) file1.deleteSync();
      if (file2.existsSync()) file2.deleteSync();
      if (file3.existsSync()) file3.deleteSync();

      final serverCompleter = Completer();
      worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (connection) => connection.read().then((value) => serverCompleter.complete(value.takeBytes())));

      final workerFile1 = worker.files.open(file1.path, create: true);
      final workerFile2 = worker.files.open(file2.path, create: true);
      final workerFile3 = worker.files.open(file3.path, create: true);

      final futures = [
        workerFile1.writeSingle(Generators.request(), submit: false),
        workerFile2.writeSingle(Generators.request(), submit: false),
        workerFile3.writeSingle(Generators.request(), submit: false),
        worker.clients.tcp(InternetAddress("127.0.0.1"), 12345).then((value) => value.select().writeSingle(Generators.request(), submit: false)),
      ];
      worker.submit(inbound: false, outbound: true);
      await serverCompleter.future.then((value) => Validators.request(value));
      await Future.wait(futures);

      await workerFile1.readSingle().then((value) => Validators.request(value.takeBytes()));
      await workerFile2.readSingle().then((value) => Validators.request(value.takeBytes()));
      await workerFile3.readSingle().then((value) => Validators.request(value.takeBytes()));

      workerFile1.close().then((value) => workerFile1.delegate.delete());
      workerFile2.close().then((value) => workerFile2.delegate.delete());
      workerFile3.close().then((value) => workerFile3.delegate.delete());

      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerInsolates).toList();
    done.close();
    await transport.shutdown();
  });
}
