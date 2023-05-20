import 'dart:async';
import 'dart:isolate';
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
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();

      var serverCompleter = Completer();
      var server = worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) => connection.writeSingle(Generators.request()).then((value) => serverCompleter.complete()));
      var clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
      await clients.select().read().then((value) => value.release());
      await serverCompleter.future;

      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      await server.close();
      await clients.close();

      if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
      if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
      if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

      serverCompleter = Completer();
      server = worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) => connection.writeMany(Generators.requestsUnordered(8)).then((value) => serverCompleter.complete()));
      clients = await worker.clients.tcp(io.InternetAddress("127.0.0.1"), 12345);
      await clients.select().read().then((value) => value.release());
      await serverCompleter.future;

      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      await server.close();
      await clients.close();

      if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
      if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
      if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown();
  });
}

void testUdpBuffers() {
  test("(udp)", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();

      var serverCompleter = Completer();
      var server = worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345);
      server.receiveSingleMessage().then((value) {
        value.release();
        value.respondSingleMessage(Generators.request()).then((value) => serverCompleter.complete());
      });
      var clients = await worker.clients.udp(io.InternetAddress("127.0.0.1"), 12346, io.InternetAddress("127.0.0.1"), 12345);
      await clients.sendSingleMessage(Generators.request());
      await clients.receiveSingleMessage().then((value) => value.release());
      await serverCompleter.future;

      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      await server.close();
      await clients.close();

      if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
      if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
      if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

      serverCompleter = Completer();
      server = worker.servers.udp(io.InternetAddress("0.0.0.0"), 12345);
      server.receiveSingleMessage().then((value) {
        value.release();
        value.respondManyMessage(Generators.requestsUnordered(8)).then((value) => serverCompleter.complete());
      });
      clients = await worker.clients.udp(io.InternetAddress("127.0.0.1"), 12346, io.InternetAddress("127.0.0.1"), 12345);
      await clients.sendSingleMessage(Generators.request());
      await clients.receiveManyMessages(8).then((value) => value.forEach((element) => element.release()));
      await serverCompleter.future;

      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      await server.close();
      await clients.close();

      if (worker.servers.registry.serverConnections.isNotEmpty) throw TestFailure("serverConnections isNotEmpty");
      if (worker.servers.registry.servers.isNotEmpty) throw TestFailure("servers isNotEmpty");
      if (worker.clients.registry.clients.isNotEmpty) throw TestFailure("clients isNotEmpty");

      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown();
  });
}

void testFileBuffers() {
  test("(file)", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final file = io.File("file");
      if (file.existsSync()) file.deleteSync();

      var fileProvider = worker.files.open(file.path, create: true);
      await fileProvider.writeSingle(Generators.request());
      await fileProvider.readSingle().then((value) => value.release());

      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      await fileProvider.close();

      if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

      if (file.existsSync()) file.deleteSync();

      fileProvider = worker.files.open(file.path, create: true);
      await fileProvider.writeMany(Generators.requestsUnordered(8));
      await fileProvider.load(blocksCount: 8);

      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      await fileProvider.close();

      if (worker.files.registry.files.isNotEmpty) throw TestFailure("files isNotEmpty");

      fileProvider.delegate.deleteSync();

      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown();
  });
}

void testBuffersOverflow() {
  test("(overflow)", () async {
    final transport = Transport(
      TransportDefaults.transport(),
      TransportDefaults.inbound().copyWith(buffersCount: 1),
      TransportDefaults.outbound().copyWith(buffersCount: 1),
    );
    final done = ReceivePort();
    transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();

      worker.servers.tcp(io.InternetAddress("0.0.0.0"), 12345, (connection) {
        connection.read().then((value) {
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
      await clients.select().writeSingle(Generators.request());
      final bytes = BytesBuilder();
      final completer = Completer();
      clients.select().listen((value, _) {
        bytes.add(value.takeBytes());
        if (bytes.length == Generators.responsesSumUnordered(6).length) {
          completer.complete();
          clients.close();
        }
      });
      await completer.future;
      Validators.responsesUnorderedSum(bytes.takeBytes(), 6);
      if (worker.inboundBuffers.used() != 0) throw TestFailure("actual: ${worker.inboundBuffers.used()}");
      if (worker.outboundBuffers.used() != 0) throw TestFailure("actual: ${worker.outboundBuffers.used()}");

      worker.transmitter!.send(null);
    });
    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown();
  });
}
