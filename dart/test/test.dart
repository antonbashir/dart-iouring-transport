import 'dart:async';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final Transport _transport = Transport(TransportDefaults.configuration(), TransportDefaults.loop());
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
  final server = _transport.connection().bind("127.0.0.1", 1234, TransportDefaults.channel()).listen((client) async {
    client.queueRead();
    final completer = Completer<String>();
    client.stringInput.listen((event) {
      if (event.isEmpty) {
        client.queueRead();
        return;
      }
      completer.complete(event);
    });
    expect(await completer.future, _data);
    client.queueWriteString(_data);
    await received.future;
    client.stop();
  }).asFuture();
  final client = _transport.connection().connect("127.0.0.1", 1234, TransportDefaults.channel()).listen((server) async {
    server.queueWriteString(_data);
    server.queueRead();
    final completer = Completer<String>();
    server.stringInput.listen((event) {
      if (event.isEmpty) {
        server.queueRead();
        return;
      }
      completer.complete(event);
    });
    expect(await completer.future, _data);
    received.complete();
    server.stop();
  }).asFuture();
  await Future.wait([client, server]);
  print("end");
}
