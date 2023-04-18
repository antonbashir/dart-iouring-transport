import 'dart:async';
import 'dart:typed_data';

import 'buffers.dart';
import 'channels.dart';
import 'constants.dart';
import 'payload.dart';
import 'callbacks.dart';

class TransportFile {
  final String path;
  final TransportChannel _channel;
  final TransportCallbacks _states;
  final TransportBuffers _buffers;

  TransportFile(this.path, this._states, this._channel, this._buffers);

  Future<TransportOutboundPayload> readBuffer({int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundRead(bufferId, completer);
    _channel.read(bufferId, int32Max, transportEventRead | transportEventFile, offset: offset);
    return completer.future.then((length) => TransportOutboundPayload(_buffers.read(bufferId, length), () => _buffers.release(bufferId)));
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, int32Max, transportEventWrite | transportEventFile, offset: offset);
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
