import 'dart:async';
import 'dart:typed_data';

import 'package:iouring_transport/transport/worker.dart';

import 'channels.dart';
import 'payload.dart';

class TransportFile {
  final TransportOutboundChannel _channel;
  final TransportCallbacks _callbacks;

  TransportFile(this._callbacks, this._channel);

  Future<TransportPayload> readBuffer({int offset = 0}) async {
    final completer = Completer<TransportPayload>();
    final bufferId = await _channel.allocate();
    _callbacks.putRead(bufferId, completer);
    _channel.read(bufferId, offset: offset);
    return completer.future;
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>();
    final bufferId = await _channel.allocate();
    _callbacks.putWrite(bufferId, completer);
    _channel.write(bytes, bufferId, offset: offset);
    return completer.future;
  }

  Future<TransportPayload> read() async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    var payload = await readBuffer(offset: offset);
    final payloads = <TransportPayload>[];
    payloads.add(payload);
    builder.add(payload.bytes);
    offset += payload.bytes.length;
    payload.release();
    while (true) {
      payload = await readBuffer(offset: offset);
      if (payload.bytes.isEmpty) {
        break;
      }
      payloads.add(payload);
      builder.add(payload.bytes);
      offset += payload.bytes.length;
      payload.release();
    }
    return TransportPayload(builder.takeBytes(), (answer, offset) => payloads.forEach((payload) => payload.release()));
  }

  void close() => _channel.close();
}
