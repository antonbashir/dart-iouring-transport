import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';
import 'validators.dart';

void testTcpBuffers() {
  test("(tcp)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();

    var serverCompleter = Completer();
    var server = worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
      connection.writeSingle(Generators.request());
      serverCompleter.complete();
    });
    var clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
    await clients.select().read().listen((value) => value.release());
    await serverCompleter.future;

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    serverCompleter = Completer();
    server = worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
      connection.writeMany(Generators.requestsUnordered(8));
      serverCompleter.complete();
    });
    clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
    await clients.select().read().listen((value) => value.release());
    await serverCompleter.future;

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    await transport.shutdown();
  });
}

void testUdpBuffers() {
  test("(udp)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker()));
    await worker.initialize();

    var serverCompleter = Completer();
    var server = worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345);
    server.receiveBySingle().listen((value) {
      value.release();
      value.respondSingleMessage(Generators.request());
      serverCompleter.complete();
    });
    var clients = await worker.clients.udp(io.InternetAddress("127.0.0.1"), 12346, io.InternetAddress("127.0.0.1"), 12345);
    clients.sendSingleMessage(Generators.request());
    clients.receiveBySingle().listen((value) => value.release());
    await serverCompleter.future;

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    serverCompleter = Completer();
    server = worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345);
    server.receiveBySingle().listen((value) {
      value.release();
      value.respondManyMessages(Generators.requestsUnordered(8));
      serverCompleter.complete();
    });
    clients = await worker.clients.udp(io.InternetAddress("127.0.0.1"), 12346, io.InternetAddress("127.0.0.1"), 12345);
    clients.sendSingleMessage(Generators.request());
    clients.receiveByMany(8).listen((value) => value.release());
    await serverCompleter.future;

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await server.close();
    await clients.close();

    if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
    if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
    if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

    await transport.shutdown();
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
    fileProvider.inbound.listen((value) => value.release());

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await fileProvider.close();

    if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

    if (file.existsSync()) file.deleteSync();

    fileProvider = worker.files.open(file.path, create: true);
    fileProvider.writeMany(Generators.requestsUnordered(8));
    await fileProvider.read(blocksCount: 8);

    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");

    await fileProvider.close();

    if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

    fileProvider.delegate.deleteSync();

    await transport.shutdown();
  });
}

void testBuffersOverflow() {
  test("(overflow)", () async {
    final transport = Transport();
    final worker = TransportWorker(transport.worker(TransportDefaults.worker().copyWith(buffersCount: 1)));
    await worker.initialize();

    worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
      connection.read().listen((value) {
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
    clients.select().read().listen((value) {
      bytes.add(value.takeBytes());
      if (bytes.length == Generators.responsesSumUnordered(6).length) {
        completer.complete();
        clients.close();
      }
    });
    await completer.future;
    Validators.responsesUnorderedSum(bytes.takeBytes(), 6);
    if (worker.buffers.used() != 0) throw TestFailure("actual: ${worker.buffers.used()}");
    await transport.shutdown();
  });
}
