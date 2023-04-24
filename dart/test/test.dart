import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'file.dart';
import 'tcp.dart';
import 'udp.dart';
import 'unix.dart';

void main() {
  group("[initialization]", () {
    testInitialization(listeners: 1, workers: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    testInitialization(listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    testInitialization(listeners: 4, workers: 4, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    testInitialization(listeners: 4, workers: 4, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    testInitialization(listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  });
  group("[tcp]", () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testTcp(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 4, workers: 4, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 4, workers: 4, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcp(index: index, listeners: 2, workers: 2, clientsPool: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[unix stream]", () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testUnixStream(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 4, workers: 4, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 4, workers: 4, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStream(index: index, listeners: 4, workers: 4, clientsPool: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[udp]", () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testUdp(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdp(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[unix dgram]", timeout: Timeout(Duration(minutes: 5)), () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testUnixDgram(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 4, workers: 4, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 4, workers: 4, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgram(index: index, listeners: 2, workers: 2, clients: 1024, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[file]", timeout: Timeout(Duration(minutes: 5)), () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testFile(index: index, listeners: 1, workers: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFile(index: index, listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFile(index: index, listeners: 4, workers: 4, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFile(index: index, listeners: 4, workers: 4, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFile(index: index, listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    }
  });
  group("[custom]", () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testCustom(index, 1);
      testCustom(index, 2);
      testCustom(index, 4);
    }
  });
}

void testInitialization({
  required int listeners,
  required int workers,
  required int listenerFlags,
  required int workerFlags,
}) {
  test("[listeners = $listeners, workers = $workers]", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(listenerIsolates: listeners, workerInsolates: workers),
      TransportDefaults.listener().copyWith(ringFlags: listenerFlags),
      TransportDefaults.inbound().copyWith(ringFlags: workerFlags),
      TransportDefaults.outbound().copyWith(ringFlags: workerFlags),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      worker.transmitter!.send(null);
    });
    await done.take(workers);
    done.close();
    await transport.shutdown();
  });
}

void testCustom(int data, int workers) {
  test("callback", () async {
    final transport = Transport(
      TransportDefaults.transport().copyWith(workerInsolates: workers),
      TransportDefaults.listener(),
      TransportDefaults.inbound(),
      TransportDefaults.outbound(),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      final completer = Completer<int>();
      await worker.initialize();
      final id = 1;
      worker.registerCallback(id, completer);
      worker.notifyCustom(id, data);
      final result = await completer.future;
      expect(result, data);
      worker.transmitter!.send(result);
    });
    await done.take(workers);
    done.close();
    await transport.shutdown();
  });
}
