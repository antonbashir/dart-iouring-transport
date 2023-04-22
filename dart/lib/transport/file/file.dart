import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../payload.dart';
import '../callbacks.dart';

class TransportFile {
  final String path;
  final TransportChannel _channel;
  final TransportCallbacks _states;
  final TransportBuffers _buffers;
  final TransportPayloadPool _pool;
  final File delegate;

  TransportFile(
    this.path,
    this.delegate,
    this._states,
    this._channel,
    this._buffers,
    this._pool,
  );

  Future<TransportPayload> read({int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundRead(bufferId, completer);
    _channel.readSubmit(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    return completer.future.then((length) => _pool.getPayload(bufferId, _buffers.read(bufferId, length)));
  }

  Stream<TransportPayload> stream() async* {
    final controller = StreamController<TransportPayload>();
    var offset = 0;
    var payload = await read(offset: offset);
    if (payload.bytes.isEmpty || payload.bytes.first == 0) {
      payload.release();
      await controller.close();
      return;
    }
    yield payload;
    offset += payload.bytes.length;
    while (true) {
      payload = await read(offset: offset);
      if (payload.bytes.isEmpty || payload.bytes.first == 0) break;
      yield payload;
      offset += payload.bytes.length;
    }
  }

  Future<Uint8List> load() async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    var payload = await read(offset: offset);
    if (payload.bytes.isEmpty || payload.bytes.first == 0) {
      payload.release();
      return Uint8List.fromList([]);
    }
    builder.add(payload.extract());
    offset += payload.bytes.length;
    while (true) {
      payload = await read(offset: offset);
      if (payload.bytes.isEmpty || payload.bytes.first == 0) break;
      builder.add(payload.extract());
      offset += payload.bytes.length;
    }
    return builder.takeBytes();
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundWrite(bufferId, completer);
    _channel.writeSubmit(bytes, bufferId, transportTimeoutInfinity, transportEventWrite | transportEventFile, offset: offset);
    return completer.future;
  }

  void close() => _channel.close();
}
