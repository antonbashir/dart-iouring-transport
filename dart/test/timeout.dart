import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/exception.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

Function _handleTimeout(Stopwatch actual, Duration expected, Completer completer) => (error) {
      if (!(error is TransportCanceledException)) throw TestFailure("actual: $error");
      if (actual.elapsed.inSeconds < expected.inSeconds) throw TestFailure("actual: ${actual.elapsed.inSeconds}");
      completer.complete();
      return null;
    };

void testTcpTimeoutSingle({
  required Duration connection,
  required Duration serverRead,
  required Duration clientRead,
}) {
  test("(timeout tcp single) [connection = ${connection.inSeconds}, serverRead = ${serverRead.inSeconds}, clientRead = ${clientRead.inSeconds}] ", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final time = Stopwatch();
      var completer = Completer();

      var server = worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (client) {});
      time.start();
      await worker.clients
          .tcp(InternetAddress("1.1.1.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(connectTimeout: connection))
          .then((_) {}, onError: _handleTimeout(time, connection, completer));
      await completer.future;
      await server.close();

      server = worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (client) {});
      time.reset();
      completer = Completer();
      await worker.clients
          .tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(readTimeout: clientRead))
          .then((value) => value.select().read())
          .then((_) {}, onError: _handleTimeout(time, clientRead, completer));
      await completer.future;
      await server.close();

      server = worker.servers.tcp(
        InternetAddress("0.0.0.0"),
        12345,
        configuration: TransportDefaults.tcpServer().copyWith(readTimeout: serverRead),
        (connection) => connection.read().then((_) {}, onError: _handleTimeout(time, serverRead, completer)),
      );
      time.reset();
      completer = Completer();
      await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345);
      await completer.future;
      await server.close();

      worker.transmitter!.send(null);
    });

    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUdpTimeoutSingle({
  required Duration serverRead,
  required Duration clientRead,
}) {
  test("(timeout udp single) [serverRead = ${serverRead.inSeconds}, clientRead = ${clientRead.inSeconds}] ", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final time = Stopwatch();
      var completer = Completer();

      var server = worker.servers.udp(InternetAddress("0.0.0.0"), 12345);
      time.start();
      await worker.clients
          .udp(InternetAddress("127.0.0.1"), 12346, InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.udpClient().copyWith(readTimeout: clientRead))
          .receiveSingleMessage()
          .then((_) {}, onError: _handleTimeout(time, clientRead, completer));
      await completer.future;
      await server.close();

      server = worker.servers.udp(InternetAddress("0.0.0.0"), 12345, configuration: TransportDefaults.udpServer().copyWith(readTimeout: serverRead));
      time.reset();
      completer = Completer();
      server.receiveSingleMessage().then((_) {}, onError: _handleTimeout(time, serverRead, completer));
      await completer.future;
      await server.close();

      worker.transmitter!.send(null);
    });

    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}

void testUdpTimeoutMany({
  required Duration serverRead,
  required Duration clientRead,
  required int count,
}) {
  test("(udp many) [serverRead = ${serverRead.inSeconds}, clientRead = ${clientRead.inSeconds}] ", () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final time = Stopwatch();
      var completer = Completer();

      var server = worker.servers.udp(InternetAddress("0.0.0.0"), 12345);
      time.start();
      await worker.clients
          .udp(InternetAddress("127.0.0.1"), 12346, InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.udpClient().copyWith(readTimeout: clientRead))
          .receiveManyMessages(count)
          .then((_) {}, onError: _handleTimeout(time, clientRead, completer));
      await completer.future;
      await server.close();

      server = worker.servers.udp(InternetAddress("0.0.0.0"), 12345, configuration: TransportDefaults.udpServer().copyWith(readTimeout: serverRead));
      time.reset();
      completer = Completer();
      server.receiveManyMessages(count).then((_) {}, onError: _handleTimeout(time, serverRead, completer));
      await completer.future;
      await server.close();

      worker.transmitter!.send(null);
    });

    await done.take(TransportDefaults.transport().workerIsolates).toList();
    done.close();
    await transport.shutdown(gracefulDuration: Duration(milliseconds: 100));
  });
}
