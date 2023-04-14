import 'dart:async';
import 'dart:typed_data';

import 'package:iouring_transport/transport/exception.dart';

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
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _client.sendMessage(bytes, flags: flags);

  @pragma(preferInlinePragma)
  Future<void> close() => _client.close();
}

class TransportServerStreamCommunicator {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerStreamCommunicator(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportInboundStreamPayload> read() => _server.read(_channel);

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => _server.write(bytes, _channel);

  void listen(void Function(TransportInboundStreamPayload paylad) listener, {void Function(dynamic error, StackTrace? stackTrace)? onError}) async {
    while (_server.active) {
      await read().then(listener, onError: (error, stackTrace) {
        if (!(error is TransportClosedException)) onError?.call(error, stackTrace);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close() => _server.close();
}

class TransportServerDatagramReceiver {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerDatagramReceiver(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportInboundDatagramPayload> receiveMessage({int? flags}) => _server.receiveMessage(_channel, flags: flags);

  void listen(void Function(TransportInboundDatagramPayload payload) listener, {void Function(Exception error)? onError, int? flags}) async {
    while (_server.active) {
      await receiveMessage(flags: flags).then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close() => _server.close();
}

class TransportInboundDatagramSender {
  final TransportServer _server;
  final TransportChannel _channel;
  final int _initialBufferId;
  final Uint8List initialPayload;

  TransportInboundDatagramSender(this._server, this._channel, this._initialBufferId, this.initialPayload);

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _server.sendMessage(bytes, _channel, flags: flags);

  @pragma(preferInlinePragma)
  void release() => _server.releaseBuffer(_initialBufferId);
}
