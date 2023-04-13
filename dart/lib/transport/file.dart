import 'dart:async';
import 'dart:typed_data';

import 'channels.dart';
import 'constants.dart';
import 'payload.dart';
import 'state.dart';

class TransportFile {
  final TransportChannel _channel;
  final Transportcallbacks _states;

  TransportFile(this._states, this._channel);

  Future<TransportOutboundPayload> readBuffer({int offset = 0}) async {
    final completer = Completer<TransportOutboundPayload>();
    final bufferId = _channel.getBuffer() ?? await _channel.allocate();
    _states.setOutboundRead(bufferId, completer);
    _channel.read(bufferId, int32Max, offset: offset);
    return completer.future;
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>();
    final bufferId = _channel.getBuffer() ?? await _channel.allocate();
    _states.setOutboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, int32Max, offset: offset);
    return completer.future;
  }

  Future<TransportOutboundPayload> read() async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    var payload = await readBuffer(offset: offset);
    final payloads = <TransportOutboundPayload>[];
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
    return TransportOutboundPayload(builder.takeBytes(), () => payloads.forEach((payload) => payload.release()));
  }

  void close() => _channel.close();
}
