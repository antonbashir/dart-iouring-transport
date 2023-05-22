import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testFileSingle({
  required int index,
  required int workers,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("(single) [index = $index, workers = $workers]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      var nativeFile = File("file-${worker.id}");
      if (nativeFile.existsSync()) nativeFile.deleteSync();
      if (!nativeFile.existsSync()) nativeFile.createSync();
      final file = worker.files.open(nativeFile.path, create: true);
      final result = await file.writeSingle(Generators.request()).then((_) => file.readSingle());
      Validators.request(result.takeBytes());
      if (nativeFile.existsSync()) nativeFile.deleteSync();
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown();
  });
}

void testFileLoad({
  required int index,
  required int workers,
  required int listenerFlags,
  required int workerFlags,
  required int count,
}) {
  test("(load) [index = $index, workers = $workers]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.worker().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      var nativeFile = File("file-${worker.id}");
      if (nativeFile.existsSync()) nativeFile.deleteSync();
      if (!nativeFile.existsSync()) nativeFile.createSync();
      final file = worker.files.open(nativeFile.path, create: true);
      final data = Generators.requestsOrdered(count * count);
      final result = await file.writeMany(data).then((_) => file.read(blocksCount: count));
      Validators.requestsSumOrdered(result, count * count);
      if (nativeFile.existsSync()) nativeFile.deleteSync();
      worker.transmitter!.send(null);
    });
    await done.take(workers).toList();
    done.close();
    await transport.shutdown();
  });
}
