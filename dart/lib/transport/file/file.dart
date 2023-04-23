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

  @pragma(preferInlinePragma)
  Future<TransportPayload> _addRead(int bufferId, {int offset = 0}) {
    final completer = Completer<int>();
    _states.setOutboundRead(bufferId, completer);
    _channel.addRead(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    return completer.future.then((length) => _pool.getPayload(bufferId, _buffers.read(bufferId, length)));
  }

  Stream<TransportPayload> stream() async* {
    var offset = 0;
    var payload = await read(offset: offset);
    if (payload.bytes.isEmpty || payload.bytes.first == 0) {
      payload.release();
      return;
    }
    offset += payload.bytes.length;
    yield payload;
    while (true) {
      payload = await read(offset: offset);
      if (payload.bytes.isEmpty || payload.bytes.first == 0) return;
      offset += payload.bytes.length;
      yield payload;
    }
  }

  Future<Uint8List> load({int batchCount = 32}) async {
    final allocatedBuffers = <int>[];
    for (var i = 0; i < batchCount; i++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    while (true) {
      for (var i = 0; i < batchCount - 1; i++) {
        _addRead(allocatedBuffers[i], offset: offset).then((fragmentPayload) {
          if (fragmentPayload.bytes.isEmpty) {
            fragmentPayload.release();
            return;
          }
          builder.add(fragmentPayload.bytes);
          fragmentPayload.release();
        });
        offset += _buffers.bufferSize;
      }
      final submitCompleter = Completer<int>();
      _states.setOutboundRead(allocatedBuffers[batchCount - 1], submitCompleter);
      _channel.readSubmit(allocatedBuffers[batchCount - 1], transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
      final payload = await submitCompleter.future.then((length) => _pool.getPayload(allocatedBuffers[batchCount - 1], _buffers.read(allocatedBuffers[batchCount - 1], length)));
      offset += _buffers.bufferSize;
      if (payload.bytes.isEmpty) {
        payload.release();
        break;
      }
      builder.add(payload.bytes);
      payload.release();
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
