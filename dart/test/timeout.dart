import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/exception.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';

Function _handleTimeout(Stopwatch actual, Duration expected) => (error) {
      if (!(error is TransportCancelledException)) throw TestFailure("actual: $error");
      if (actual.elapsed.inSeconds < expected.inSeconds) throw TestFailure("actual: ${actual.elapsed.inSeconds}");
      return null;
    };

void testTcpTimeoutSingle({
  required Duration connection,
  required Duration serverRead,
  required Duration serverWrite,
  required Duration clientRead,
  required Duration clientWrite,
}) {
  test(
      "(tcp) [connection = ${connection.inSeconds}, serverRead = ${serverRead.inSeconds}, serverWrite = ${serverWrite.inSeconds}, clientRead = ${clientRead.inSeconds}, clientWrite = ${clientWrite.inSeconds}] ",
      () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.listener(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final time = Stopwatch();

      worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (client) {});

      time.start();
      await worker.clients
          .tcp(InternetAddress("1.1.1.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(connectTimeout: connection))
          .then((_) {}, onError: _handleTimeout(time, connection));

      time.reset();
      await worker.clients
          .tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(readTimeout: clientRead))
          .then((value) => value.select().read())
          .then((_) {}, onError: _handleTimeout(time, clientRead));

      time.reset();
      await worker.clients
          .tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(writeTimeout: clientWrite))
          .then((value) => value.select().writeSingle(Generators.request()))
          .then((_) {}, onError: _handleTimeout(time, clientWrite));

      time.reset();
      worker.servers.tcp(
        InternetAddress("0.0.0.0"),
        12345,
        configuration: TransportDefaults.tcpServer().copyWith(readTimeout: serverRead),
        (connection) => connection.read().then((_) {}, onError: _handleTimeout(time, serverRead)),
      );
      await (await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345)).close();

      time.reset();
      worker.servers.tcp(
        InternetAddress("0.0.0.0"),
        12345,
        configuration: TransportDefaults.tcpServer().copyWith(writeTimeout: serverWrite),
        (connection) => connection.writeSingle(Generators.request()).then((_) {}, onError: _handleTimeout(time, serverWrite)),
      );
      await (await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345)).close();

      worker.transmitter!.send(null);
    });

    await done.take(TransportDefaults.transport().workerInsolates).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUnixStreamTimeoutSingle({
  required Duration serverRead,
  required Duration serverWrite,
  required Duration clientRead,
  required Duration clientWrite,
}) {
  test("(unix stream) [serverRead = ${serverRead.inSeconds}, serverWrite = ${serverWrite.inSeconds}, clientRead = ${clientRead.inSeconds}, clientWrite = ${clientWrite.inSeconds}] ", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.listener(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final time = Stopwatch();

      final serverSocket = File(Directory.current.path + "/socket_${worker.id}.sock");
      if (serverSocket.existsSync()) serverSocket.deleteSync();

      var server = worker.servers.unixStream(serverSocket.path, (client) {});

      time.start();
      await worker.clients
          .unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(readTimeout: clientRead))
          .then((value) => value.select().read())
          .then((_) {}, onError: _handleTimeout(time, clientRead));

      time.reset();
      await worker.clients
          .unixStream(serverSocket.path, configuration: TransportDefaults.unixStreamClient().copyWith(writeTimeout: clientWrite))
          .then((value) => value.select().writeSingle(Generators.request()))
          .then((_) {}, onError: _handleTimeout(time, clientWrite));

      await server.close();

      time.reset();
      server = worker.servers.unixStream(
        serverSocket.path,
        configuration: TransportDefaults.unixStreamServer().copyWith(readTimeout: serverRead),
        (connection) => connection.read().then((_) {}, onError: _handleTimeout(time, serverRead)),
      );
      await (await worker.clients.unixStream(serverSocket.path)).close();

      await server.close();

      time.reset();
      server = worker.servers.unixStream(
        serverSocket.path,
        configuration: TransportDefaults.unixStreamServer().copyWith(writeTimeout: serverWrite),
        (connection) => connection.writeSingle(Generators.request()).then((_) {}, onError: _handleTimeout(time, serverWrite)),
      );
      await (await worker.clients.unixStream(serverSocket.path)).close();

      worker.transmitter!.send(null);
    });

    await done.take(TransportDefaults.transport().workerInsolates).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testDatagramTimeoutSingle() {}

void testFileTimeoutSingle() {}

void testStreamTimeoutMany() {}

void testDatagramTimeoutMany() {}

void testFileTimeoutMany() {}
