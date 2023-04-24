import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

void testFile({
  required int index,
  required int listeners,
  required int workers,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("[index = $index, listeners = $listeners, workers = $workers]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(listenerIsolates: listeners, workerInsolates: workers),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    final data = Utf8Encoder().convert("data");
    await transport.run(transmitter: done.sendPort, (input) async {
      final data = Utf8Encoder().convert("data");
      final worker = TransportWorker(input);
      await worker.initialize();
      var nativeFile = File("file-${worker.id}");
      if (nativeFile.existsSync()) nativeFile.deleteSync();
      if (!nativeFile.existsSync()) nativeFile.createSync();
      final file = worker.files.open(nativeFile.path);
      await file.writeSingle(data).then((_) => file.readSingle()).then((value) => worker.transmitter!.send(value.takeBytes()));
      if (nativeFile.existsSync()) nativeFile.deleteSync();
    });
    (await done.take(workers).toList()).forEach((response) => expect(response, data));
    done.close();
    await transport.shutdown();
  });
}
