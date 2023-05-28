import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testFileSingle({required int index}) {
  test("(single) [index = $index]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    var nativeFile = File("file-${worker.id}");
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    if (!nativeFile.existsSync()) nativeFile.createSync();
    final file = worker.files.open(nativeFile.path, create: true);
    file.writeSingle(Generators.request());
    Validators.request(await file.load());
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    await transport.shutdown();
  });
}

void testFileLoad({required int index, required int count}) {
  test("(load) [index = $index, count = $count]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    var nativeFile = File("file-${worker.id}");
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    if (!nativeFile.existsSync()) nativeFile.createSync();
    final file = worker.files.open(nativeFile.path, create: true);
    final data = Generators.requestsOrdered(count * count);
    final completer = Completer();
    file.writeMany(data, onDone: () async {
      Validators.requestsSumOrdered(await file.load(blocksCount: count), count * count);
      completer.complete();
    });
    await completer.future;
    await file.close();
    Validators.requestsSumOrdered(await worker.files.open(nativeFile.path, create: true).load(blocksCount: 1), count * count);
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    await transport.shutdown();
  });
}
