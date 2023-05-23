import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testFileSingle({
  required int index,
}) {
  test("(single) [index = $index]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    var nativeFile = File("file-${worker.id}");
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    if (!nativeFile.existsSync()) nativeFile.createSync();
    final file = worker.files.open(nativeFile.path, create: true);
    file.writeSingle(Generators.request());
    Validators.request(await file.read());
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    await transport.shutdown();
  });
}

void testFileLoad({
  required int index,
  required int count,
}) {
  test("(load) [index = $index]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    var nativeFile = File("file-${worker.id}");
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    if (!nativeFile.existsSync()) nativeFile.createSync();
    final file = worker.files.open(nativeFile.path, create: true);
    final data = Generators.requestsOrdered(count * count);
    file.writeMany(data);
    final result = await file.read(blocksCount: count);
    Validators.requestsSumOrdered(result, count * count);
    if (nativeFile.existsSync()) nativeFile.deleteSync();
    await transport.shutdown();
  });
}
