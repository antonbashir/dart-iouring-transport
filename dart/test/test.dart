import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/constants.dart';
import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'buffers.dart';
import 'bulk.dart';
import 'file.dart';
import 'shutdown.dart';
import 'tcp.dart';
import 'timeout.dart';
import 'udp.dart';
import 'unix.dart';

void main() {
  final initialization = false;
  final tcp = false;
  final udp = false;
  final unixStream = false;
  final unixDgram = false;
  final file = true;
  final timeout = false;
  final buffers = false;
  final shutdown = false;
  final bulk = false;

  group("[initialization]", timeout: Timeout(Duration(hours: 1)), skip: !initialization, () {
    testInitialization(listeners: 1, workers: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    testInitialization(listeners: 1, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
    testInitialization(listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
  });
  group("[tcp]", timeout: Timeout(Duration(hours: 1)), skip: !tcp, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testTcpSingle(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcpSingle(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcpSingle(index: index, listeners: 1, workers: 2, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcpSingle(index: index, listeners: 1, workers: 2, clientsPool: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testTcpMany(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 64);
      testTcpMany(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 32);
      testTcpMany(index: index, listeners: 1, workers: 2, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 8);
      testTcpMany(index: index, listeners: 2, workers: 2, clientsPool: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 4);
    }
  });
  group("[unix stream]", timeout: Timeout(Duration(hours: 1)), skip: !unixStream, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testUnixStreamSingle(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStreamSingle(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStreamSingle(index: index, listeners: 1, workers: 2, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStreamSingle(index: index, listeners: 1, workers: 2, clientsPool: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixStreamMany(index: index, listeners: 1, workers: 1, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 64);
      testUnixStreamMany(index: index, listeners: 2, workers: 2, clientsPool: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 32);
      testUnixStreamMany(index: index, listeners: 1, workers: 2, clientsPool: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 8);
      testUnixStreamMany(index: index, listeners: 1, workers: 2, clientsPool: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 4);
    }
  });
  group("[udp]", timeout: Timeout(Duration(hours: 1)), skip: !udp, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testUdpSingle(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdpSingle(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdpSingle(index: index, listeners: 1, workers: 2, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdpSingle(index: index, listeners: 2, workers: 2, clients: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUdpMany(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 8);
      testUdpMany(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 4);
      testUdpMany(index: index, listeners: 1, workers: 2, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 2);
      testUdpMany(index: index, listeners: 2, workers: 2, clients: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 2);
    }
  });
  group("[unix dgram]", timeout: Timeout(Duration(hours: 1)), skip: !unixDgram, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testUnixDgramSingle(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgramSingle(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgramSingle(index: index, listeners: 1, workers: 2, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgramSingle(index: index, listeners: 2, workers: 2, clients: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testUnixDgramMany(index: index, listeners: 1, workers: 1, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 8);
      testUnixDgramMany(index: index, listeners: 2, workers: 2, clients: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 4);
      testUnixDgramMany(index: index, listeners: 1, workers: 2, clients: 128, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 2);
      testUnixDgramMany(index: index, listeners: 2, workers: 2, clients: 512, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 2);
    }
  });
  group("[file]", timeout: Timeout(Duration(hours: 1)), skip: !file, () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testFileSingle(index: index, listeners: 1, workers: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFileSingle(index: index, listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFileSingle(index: index, listeners: 1, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFileSingle(index: index, listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll);
      testFileLoad(index: index, listeners: 1, workers: 1, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 64);
      testFileLoad(index: index, listeners: 2, workers: 2, listenerFlags: 0, workerFlags: ringSetupSqpoll, count: 32);
    }
  });
  group("[timeout]", timeout: Timeout(Duration(hours: 1)), skip: !timeout, () {
    testTcpTimeoutSingle(connection: Duration(seconds: 1), serverRead: Duration(seconds: 5), clientRead: Duration(seconds: 3));
    testUdpTimeoutSingle(serverRead: Duration(seconds: 5), clientRead: Duration(seconds: 3));
    testUdpTimeoutMany(serverRead: Duration(seconds: 5), clientRead: Duration(seconds: 3), count: 8);
  });
  group("[buffers]", timeout: Timeout(Duration(hours: 1)), skip: !buffers, () {
    testTcpBuffers();
    testUdpBuffers();
    testFileBuffers();
    testBuffersOverflow();
  });
  group("[shutdown]", timeout: Timeout(Duration(hours: 1)), skip: !shutdown, () {
    testShutdown(gracefulDuration: Duration(seconds: 10));
  });
  group("[bulk]", timeout: Timeout(Duration(hours: 1)), skip: !bulk, () {
    testBulk();
  });
  group("[custom]", timeout: Timeout(Duration(hours: 1)), () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testCustom(index, 1);
      testCustom(index, 2);
      testCustom(index, 4);
    }
  });
  testDomain();
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

void testCustom(int index, int workers) {
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
      worker.notifyCustom(id, index);
      final result = await completer.future;
      worker.transmitter!.send(result);
    });
    (await done.take(workers).toList()).forEach((element) => expect(element, index));
    done.close();
    await transport.shutdown();
  });
}

void testDomain() {
  test("[domain]", () async {
    final transport = Transport(
      TransportDefaults.transport(),
      TransportDefaults.listener(),
      TransportDefaults.inbound(),
      TransportDefaults.outbound(),
    );
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final address = (await InternetAddress.lookup("google.com")).first;
      final clients = await worker.clients.tcp(address, 443);
      await clients.select().writeSingle(Utf8Encoder().convert("GET"));
      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerInsolates).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
