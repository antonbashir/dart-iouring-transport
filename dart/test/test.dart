import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final initialization = true;
  final callback = true;
  final domain = true;
  final shutdown = true;

  final tcp = true;
  final udp = false;
  final unixStream = false;
  final unixDgram = false;
  final file = false;
  final timeout = false;
  final buffers = false;
  final bulk = false;

  group("[initialization]", timeout: Timeout(Duration(hours: 1)), skip: !initialization, () {
    testInitialization();
  });
  group("[shutdown]", timeout: Timeout(Duration(hours: 1)), skip: !shutdown, () {
    testShutdown(gracefulDuration: Duration(seconds: 10));
  });
  group("[callback]", timeout: Timeout(Duration(hours: 1)), skip: !callback, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testCustom(index, 1);
      testCustom(index, 2);
      testCustom(index, 4);
    }
  });
  group("[domain]", skip: !domain, () => testDomain());
  group("[tcp]", timeout: Timeout(Duration(hours: 1)), skip: !tcp, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testTcpSingle(index: index, clientsPool: 1);
      testTcpSingle(index: index, clientsPool: 128);
      testTcpSingle(index: index, clientsPool: 512);
      testTcpMany(index: index, clientsPool: 1, count: 64);
      testTcpMany(index: index, clientsPool: 1, count: 32);
      testTcpMany(index: index, clientsPool: 128, count: 8);
      testTcpMany(index: index, clientsPool: 512, count: 4);
    }
  });
  group("[unix stream]", timeout: Timeout(Duration(hours: 1)), skip: !unixStream, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testUnixStreamSingle(index: index, clientsPool: 1);
      testUnixStreamSingle(index: index, clientsPool: 128);
      testUnixStreamSingle(index: index, clientsPool: 512);
      testUnixStreamMany(index: index, clientsPool: 1, count: 64);
      testUnixStreamMany(index: index, clientsPool: 1, count: 32);
      testUnixStreamMany(index: index, clientsPool: 128, count: 8);
      testUnixStreamMany(index: index, clientsPool: 512, count: 4);
    }
  });
  group("[udp]", timeout: Timeout(Duration(hours: 1)), skip: !udp, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testUdpSingle(index: index, clients: 1);
      testUdpSingle(index: index, clients: 128);
      testUdpSingle(index: index, clients: 512);
      testUdpMany(index: index, clients: 1, count: 8);
      testUdpMany(index: index, clients: 1, count: 4);
      testUdpMany(index: index, clients: 128, count: 2);
      testUdpMany(index: index, clients: 512, count: 2);
    }
  });
  group("[unix dgram]", timeout: Timeout(Duration(hours: 1)), skip: !unixDgram, () {
    final testsCount = 10;
    for (var index = 0; index < testsCount; index++) {
      testUnixDgramSingle(index: index, clients: 1);
      testUnixDgramSingle(index: index, clients: 128);
      testUnixDgramSingle(index: index, clients: 512);
      testUnixDgramMany(index: index, clients: 1, count: 8);
      testUnixDgramMany(index: index, clients: 1, count: 4);
      testUnixDgramMany(index: index, clients: 128, count: 2);
      testUnixDgramMany(index: index, clients: 512, count: 2);
    }
  });
  group("[file]", timeout: Timeout(Duration(hours: 1)), skip: !file, () {
    final testsCount = 5;
    for (var index = 0; index < testsCount; index++) {
      testFileSingle(index: index);
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
  group("[bulk]", timeout: Timeout(Duration(hours: 1)), skip: !bulk, () {
    testBulk();
  });
}

void testInitialization() {
  test("(initialize)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    await transport.shutdown();
  });
}

void testCustom(int index, int result) {
  test("(callback) [index=$index, result=$result]", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    final completer = Completer<int>();
    await worker.initialize();
    final id = 1;
    worker.registerCallback(id, completer);
    worker.notifyCustom(id, result);
    expect(await completer.future, result);
    await transport.shutdown();
  });
}

void testDomain() {
  test("(domain)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final address = (await InternetAddress.lookup("google.com")).first;
    final clients = await worker.clients.tcp(address, 443);
    clients.select().writeSingle(Utf8Encoder().convert("GET"), onError: (error) => fail(error.toString()));
    await Future.delayed(Duration(seconds: 1));
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
