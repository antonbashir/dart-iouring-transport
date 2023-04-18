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

  Future<Uint8List> read() async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    var payload = await readBuffer(offset: offset);
    if (payload.bytes.isEmpty) {
      payload.release();
      return Uint8List.fromList([]);
    }
    builder.add(payload.extract());
    offset += payload.bytes.length;
    while (true) {
      payload = await readBuffer(offset: offset);
      if (payload.bytes.isEmpty) break;
      builder.add(payload.extract());
      offset += payload.bytes.length;
    }
    return builder.takeBytes();
  }

  Future<void> transfer(TransportFile to) async {
    var offset = 0;
    var payload = await readBuffer(offset: offset);
    if (payload.bytes.isEmpty) {
      payload.release();
      return;
    }
    await to.write(payload.bytes);
    offset += payload.bytes.length;
    while (true) {
      payload = await readBuffer(offset: offset);
      if (payload.bytes.isEmpty) break;
      payload.release();
      await to.write(payload.bytes, offset: offset);
      offset += payload.bytes.length;
    }
  }

  void close() => _channel.close();
}
