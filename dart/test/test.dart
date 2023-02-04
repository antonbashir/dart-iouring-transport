import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final Transport _transport = Transport(TransportDefaults.transport(), TransportDefaults.controller());
final _data = "data";
final _file = "file.txt";

void main() {
  setUpAll(() => _transport.initialize());
  tearDownAll(() => _transport.close());

  group("[files]", () {
    test("read", testFileRead);
    test("write", testFileWrite);
  });

  group("[client-server]", () {
    test("ping-pong", testClientServer);
  });
}

Future<void> testFileRead() async {
  final file = File(_file);
  if (file.existsSync()) file.deleteSync();
  if (!file.existsSync()) file.createSync();
  file.writeAsStringSync(_data);
  final channel = _transport.file(_file, TransportDefaults.channel());
  expect(await channel.readString(), _data);
  file.deleteSync();
  channel.stop();
}

Future<void> testFileWrite() async {
  final file = File(_file);
  if (file.existsSync()) file.deleteSync();
  final channel = _transport.file(_file, TransportDefaults.channel());
  await channel.writeString(_data);
  expect(file.existsSync(), true);
  expect(file.readAsStringSync(), _data);
  file.deleteSync();
  channel.stop();
}

Future<void> testClientServer() async {
  final received = Completer();
  final serverTransport = Transport(TransportDefaults.transport(), TransportDefaults.controller())..initialize();
  final clientTransport = Transport(TransportDefaults.transport(), TransportDefaults.controller())..initialize();
  final serverConnection = serverTransport.connection(TransportDefaults.connection(), TransportDefaults.channel());
  final clientConnection = clientTransport.connection(TransportDefaults.connection(), TransportDefaults.channel());
  final server = serverConnection.bind("127.0.0.1", 5678).listen((client) async {
    final completer = Completer<String>();
    client.start(onRead: (payload) {
      if (payload.bytes.isEmpty) {
        client.queueRead();
        payload.finalize();
        return;
      }
      completer.complete(Utf8Decoder().convert(payload.bytes));
      payload.finalize();
    });
    client.queueRead();
    expect(await completer.future, _data);
    client.queueWrite(Utf8Encoder().convert(_data));
    await received.future;
    client.stop();
  }).asFuture();
  final client = clientConnection.connect("127.0.0.1", 5678).listen((server) async {
    final completer = Completer<String>();
    server.start(onRead: (payload) {
      if (payload.bytes.isEmpty) {
        server.queueRead();
        payload.finalize();
        return;
      }
      completer.complete(Utf8Decoder().convert(payload.bytes));
      payload.finalize();
    });
    server.queueWrite(Utf8Encoder().convert(_data));
    server.queueRead();
    expect(await completer.future, _data);
    received.complete();
    server.stop();
  }).asFuture();
  await Future.wait([client, server]);
  serverConnection.close();
  clientConnection.close();
}
