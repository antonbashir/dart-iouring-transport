import 'dart:io';
import 'dart:isolate';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/exception.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:iouring_transport/transport/worker.dart';
import 'package:test/test.dart';

import 'generators.dart';

void testTcpTimeoutSingle({
  required Duration connection,
  required Duration serverRead,
  required Duration serverWrite,
  required Duration clientRead,
  required Duration clientWrite,
}) {
  test(
      "(stream) [connection = ${connection.inSeconds}, serverRead = ${serverRead.inSeconds}, serverWrite = ${serverWrite.inSeconds}, clientRead = ${clientRead.inSeconds}, clientWrite = ${clientWrite.inSeconds}] ",
      () async {
    final transport = Transport(TransportDefaults.transport(), TransportDefaults.listener(), TransportDefaults.inbound(), TransportDefaults.outbound());
    final done = ReceivePort();
    await transport.run(transmitter: done.sendPort, (input) async {
      final worker = TransportWorker(input);
      await worker.initialize();
      final time = Stopwatch();

      time.start();
      worker.servers.tcp(InternetAddress("0.0.0.0"), 12345, (client) {});
      await worker.clients.tcp(InternetAddress("1.1.1.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(connectTimeout: connection)).then(
        (_) {},
        onError: (error) {
          if (!(error is TransportCancelledException)) throw TestFailure("actual: $error");
          if (time.elapsed.inSeconds < connection.inSeconds) throw TestFailure("actual: ${time.elapsed.inSeconds}");
          return null;
        },
      );

      time.reset();
      await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(readTimeout: clientRead)).then((value) => value.select().read()).then(
        (_) {},
        onError: (error) {
          (error) {
            if (!(error is TransportCancelledException)) throw TestFailure("actual: $error");
            if (time.elapsed.inSeconds < connection.inSeconds) throw TestFailure("actual: ${time.elapsed.inSeconds}");
            return null;
          };
        },
      );

      time.reset();
      await worker.clients
          .tcp(InternetAddress("127.0.0.1"), 12345, configuration: TransportDefaults.tcpClient().copyWith(writeTimeout: clientWrite))
          .then((value) => value.select().writeSingle(Generators.request()))
          .then(
        (_) {},
        onError: (error, _) {
          if (!(error is TransportCancelledException)) throw TestFailure("actual: $error");
          if (time.elapsed.inSeconds < clientWrite.inSeconds) throw TestFailure("actual: ${time.elapsed.inSeconds}");
          return null;
        },
      );

      time.reset();
      worker.servers.tcp(
        InternetAddress("0.0.0.0"),
        12345,
        configuration: TransportDefaults.tcpServer().copyWith(readTimeout: serverRead),
        (connection) => connection.read().then((_) {}, onError: (error, stackTrace) {
          if (!(error is TransportCancelledException)) throw TestFailure("actual: $error");
          if (time.elapsed.inSeconds < serverRead.inSeconds) throw TestFailure("actual: ${time.elapsed.inSeconds}");
          return null;
        }),
      );
      await (await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345)).close();

      time.reset();
      worker.servers.tcp(
        InternetAddress("0.0.0.0"),
        12345,
        configuration: TransportDefaults.tcpServer().copyWith(writeTimeout: serverWrite),
        (connection) => connection.writeSingle(Generators.request()).catchError((error, stackTrace) {
          if (!(error is TransportCancelledException)) throw TestFailure("actual: $error");
          if (time.elapsed.inSeconds < serverWrite.inSeconds) throw TestFailure("actual: ${time.elapsed.inSeconds}");
        }),
      );

      await (await worker.clients.tcp(InternetAddress("127.0.0.1"), 12345)).close();
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
