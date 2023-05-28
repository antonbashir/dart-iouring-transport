import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testBulk() {
  test("bulk", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final file1 = File("file1");
    final file2 = File("file2");
    final file3 = File("file3");
    if (file1.existsSync()) file1.deleteSync();
    if (file2.existsSync()) file2.deleteSync();
    if (file3.existsSync()) file3.deleteSync();

    final serverCompleter = Completer();
    worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (connection) => connection.stream().listen((value) => serverCompleter.complete(value.takeBytes())));

    final workerFile1 = worker.files.open(file1.path, create: true);
    final workerFile2 = worker.files.open(file2.path, create: true);
    final workerFile3 = worker.files.open(file3.path, create: true);

    workerFile1.writeSingle(Generators.request());
    workerFile2.writeSingle(Generators.request());
    workerFile3.writeSingle(Generators.request());
    worker.clients.tcp(InternetAddress("127.0.0.1"), 12345).then((value) => value.select().writeSingle(Generators.request()));
    await serverCompleter.future.then((value) => Validators.request(value));

    await workerFile1.load().then((value) => Validators.request(value));
    await workerFile2.load().then((value) => Validators.request(value));
    await workerFile3.load().then((value) => Validators.request(value));

    workerFile1.close().then((value) => workerFile1.delegate.delete());
    workerFile2.close().then((value) => workerFile2.delegate.delete());
    workerFile3.close().then((value) => workerFile3.delegate.delete());

    await transport.shutdown();
  });
}
