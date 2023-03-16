import 'dart:convert';
import 'dart:io';

import 'package:iouring_transport/transport/defaults.dart';
import 'package:iouring_transport/transport/transport.dart';
import 'package:test/test.dart';

final Transport _transport = Transport(
  TransportDefaults.transport(),
  TransportDefaults.acceptor(),
  TransportDefaults.channel(),
  TransportDefaults.connector(),
);

void main() {
  test("simple", timeout: Timeout(Duration(seconds: 5)), () async {
    final loop = await _transport.run();
    loop.serve("0.0.0.0", 12345, onAccept: (channel, descriptor) => channel.read(descriptor)).listen((event) => event.respond(Utf8Encoder().convert("${Utf8Decoder().convert(event.bytes)}, world")));
    await loop.awaitServer();
    _transport.logger.info("Served");
    final connector = await loop.provider.connector.connect("127.0.0.1", 12345);
    await connector.select().write(Utf8Encoder().convert("Hello"));
    final response = await connector.select().read();
    expect(Utf8Decoder().convert(response.release()), "Hello, wolrd");
    exit(0);
  });
}
