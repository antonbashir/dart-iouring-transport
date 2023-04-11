import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'payload.dart';
import 'server.dart';

class TransportClientCommunicator {
  final TransportClient _client;

  TransportClientCommunicator(this._client);

  Future<TransportOutboundPayload> read() => _client.read();

  Future<void> write(Uint8List bytes) => _client.write(bytes);

  Future<TransportOutboundPayload> receiveMessage({int? flags}) => _client.receiveMessage(flags: flags);

  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _client.sendMessage(bytes, flags: flags);

  Future<void> close() => _client.close();
}

class TransportServerStreamCommunicator {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerStreamCommunicator(this._server, this._channel);

  Future<TransportInboundStreamPayload> read() async {
    final bufferId = await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<TransportPayload>();
    _server.eventStates.setInboundRead(bufferId, completer);
    _channel.read(bufferId, _server.readTimeout, offset: 0);
    return completer.future.then((payload) => TransportInboundStreamPayload(
          payload.bytes,
          payload.releaser,
          (bytes) {
            if (!_server.active) throw TransportClosedException.forServer();
            payload.reuser();
            final completer = Completer<void>();
            _server.eventStates.setInboundWrite(bufferId, completer);
            _channel.write(bytes, bufferId, _server.writeTimeout);
            return completer.future;
          },
        ));
  }

  Future<void> close() => _server.close();
}

class TransportServerDatagramCommunicator {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerDatagramCommunicator(this._server, this._channel);

  Future<TransportInboundDatagramPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<TransportPayload>();
    _server.eventStates.setInboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, _server.pointer.ref.family, _server.readTimeout, flags);
    return completer.future.then((payload) => TransportInboundDatagramPayload(
          payload.bytes,
          payload.releaser,
          (bytes, flags) {
            if (!_server.active) throw TransportClosedException.forServer();
            payload.reuser();
            final completer = Completer<void>();
            _server.eventStates.setInboundWrite(bufferId, completer);
            _channel.respondMessage(bytes, bufferId, _server.pointer.ref.family, _server.writeTimeout, flags);
            return completer.future;
          },
        ));
  }

  Future<void> close() => _server.close();
}
