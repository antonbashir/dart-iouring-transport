import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'latch.dart';
import 'validators.dart';

void testTcpBuffers() {
  test("(tcp)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();

    var serverCompleter = Completer();
    var clientCompleter = Completer();
    var server = worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
      connection.writeSingle(Generators.request());
      serverCompleter.complete();
    });
    var clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
    await clients.select().stream().listen((value) {
      value.release();
      clientCompleter.complete();
    });
    await serverCompleter.future;
    await clientCompleter.future;

    if (worker.buffers.used() != 1) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    serverCompleter = Completer();
    clientCompleter = Completer();
    final clientBuffer = BytesBuilder();
    server = worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
      connection.writeMany(Generators.requestsUnordered(8));
      serverCompleter.complete();
    });
    clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
    await clients.select().stream().listen((value) {
      clientBuffer.add(value.takeBytes());
      if (clientBuffer.length == Generators.requestsSumUnordered(8).length) {
        clientCompleter.complete();
      }
    });
    await serverCompleter.future;
    await clientCompleter.future;

    if (worker.buffers.used() != 1) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUdpBuffers() {
  test("(udp)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();

    var serverCompleter = Completer();
    var clientCompleter = Completer();
    var server = worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345);
    server.receive().listen((value) {
      value.release();
      value.respond(Generators.request());
      serverCompleter.complete();
    });
    var clients = await worker.clients.udp(io.InternetAddress("127.0.0.1"), 12346, io.InternetAddress("127.0.0.1"), 12345);
    clients.send(Generators.request());
    clients.stream().listen((value) {
      value.release();
      clientCompleter.complete();
    });
    await serverCompleter.future;
    await clientCompleter.future;

    if (worker.buffers.used() != 2) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    serverCompleter = Completer();
    final clientLatch = Latch(8);
    server = worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345);
    server.receive().listen((value) {
      value.release();
      for (var i = 0; i < 8; i++) value.respond(Generators.request());
      serverCompleter.complete();
    });
    clients = await worker.clients.udp(io.InternetAddress("127.0.0.1"), 12346, io.InternetAddress("127.0.0.1"), 12345);
    clients.send(Generators.request());
    clients.stream().listen((value) {
      value.release();
      clientLatch.countDown();
    });
    await serverCompleter.future;
    await clientLatch.done();

    if (worker.buffers.used() != 2) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testFileBuffers() {
  test("(file)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();
    final file = io.File("file");
    if (file.existsSync()) file.deleteSync();

    var fileProvider = worker.files.open(file.path, create: true);
    fileProvider.writeSingle(Generators.request());
    await fileProvider.load();

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await fileProvider.close();

    if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

    if (file.existsSync()) file.deleteSync();

    fileProvider = worker.files.open(file.path, create: true);
    fileProvider.writeMany(Generators.requestsUnordered(8));
    await fileProvider.load(blocksCount: 8);

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await fileProvider.close();

    if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

    fileProvider.delegate.deleteSync();

    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testBuffersOverflow() {
  test("(overflow)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker().copyWith(buffersCount: 2)));
    await worker.initialize();

    worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
      connection.stream().listen((value) {
        value.release();
        connection.writeSingle(Generators.response());
        connection.writeSingle(Generators.response());
        connection.writeSingle(Generators.response());
        connection.writeSingle(Generators.response());
        connection.writeSingle(Generators.response());
        connection.writeSingle(Generators.response());
      });
    });
    var clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
    clients.select().writeSingle(Generators.request());
    final bytes = BytesBuilder();
    final completer = Completer();
    clients.select().stream().listen((value) {
      bytes.add(value.takeBytes());
      if (bytes.length == Generators.responsesSumUnordered(6).length) {
        completer.complete();
      }
    });
    await completer.future;
    Validators.responsesSumUnordered(bytes.takeBytes(), 6);
    if (worker.buffers.used() != 2) throw TestFailure("actual: ${worker.buffers.used()}");
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
