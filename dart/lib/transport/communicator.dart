import 'dart:async';
import 'dart:typed_data';

import 'exception.dart';
import 'buffers.dart';
import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'payload.dart';
import 'server.dart';

class TransportClientStreamCommunicator {
  final TransportClient _client;

  TransportClientStreamCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> read() => _client.read();

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (_client.active) {
      await read().then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => _client.write(bytes);

  Future<void> close() => _client.close();
}

class TransportClientDatagramCommunicator {
  final TransportClient _client;

  TransportClientDatagramCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> receiveMessage({int? flags}) => _client.receiveMessage(flags: flags);

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (_client.active) {
      await receiveMessage().then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) {
    return _client.sendMessage(bytes, flags: flags).then((value) => value, onError: (_) => Future.delayed(Duration(milliseconds: 100)).then((_) => sendMessage(bytes, flags: flags)));
  }

  @pragma(preferInlinePragma)
  Future<void> close() => _client.close();
}

class TransportServerConnection {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerConnection(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportInboundStreamPayload> read() => _server.read(_channel);

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => _server.write(bytes, _channel);

  void listen(void Function(TransportInboundStreamPayload paylad) listener, {void Function(dynamic error, StackTrace? stackTrace)? onError}) async {
    while (_server.active && _server.connectionIsActive(_channel.fd)) {
      await read().then((value) {
        listener(value);
      }, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        onError?.call(error, stackTrace);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close() => _server.closeConnection(_channel.fd);
}

class TransportServerDatagramReceiver {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerDatagramReceiver(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportInboundDatagramPayload> receiveMessage({int? flags}) => _server.receiveMessage(_channel, flags: flags);

  void listen(void Function(TransportInboundDatagramPayload payload) listener, {void Function(Exception error, StackTrace stackTrace)? onError, int? flags}) async {
    while (_server.active) {
      await receiveMessage(flags: flags).then((value) {
        listener(value);
      }, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        onError?.call(error, stackTrace);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close() => _server.close();
}

class TransportInboundDatagramSender {
  final TransportServer _server;
  final TransportChannel _channel;
  final TransportBuffers _buffers;
  final int _initialBufferId;
  final Uint8List initialPayload;

  TransportInboundDatagramSender(this._server, this._channel, this._buffers, this._initialBufferId, this.initialPayload);

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _server.sendMessage(bytes, _initialBufferId, _channel, flags: flags);

  @pragma(preferInlinePragma)
  void release() => _buffers.release(_initialBufferId);
}
