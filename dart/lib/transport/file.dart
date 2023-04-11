import 'dart:async';
import 'dart:typed_data';

import 'package:iouring_transport/transport/configuration.dart';
import 'package:iouring_transport/transport/retry.dart';
import 'package:iouring_transport/transport/state.dart';

import 'callbacks.dart';
import 'channels.dart';
import 'payload.dart';

class TransportFile {
  final TransportOutboundChannel _channel;
  final TransportEventStates _states;
  final TransportRetryConfiguration _retryConfiguration;

  TransportFile(this._states, this._channel, this._retryConfiguration);

  Future<TransportOutboundPayload> readBuffer({int offset = 0}) async {
    final completer = Completer<TransportOutboundPayload>();
    final bufferId = await _channel.allocate();
    _states.setOutboundReadCallback(bufferId, completer, TransportRetryState(_retryConfiguration, offset));
    _channel.read(bufferId, -1, offset: offset);
    return completer.future;
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>();
    final bufferId = await _channel.allocate();
    _states.setOutboundWriteCallback(bufferId, completer, TransportRetryState(_retryConfiguration, offset));
    _channel.write(bytes, bufferId, -1, offset: offset);
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
