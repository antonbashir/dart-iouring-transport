import 'dart:async';
import 'dart:typed_data';

import 'buffers.dart';
import 'channels.dart';
import 'client.dart';
import 'configuration.dart';
import 'constants.dart';
import 'exception.dart';
import 'payload.dart';
import 'server.dart';

class TransportClientStreamCommunicator {
  final TransportClient _client;

  TransportClientStreamCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> read() => _client.readFlush();

  @pragma(preferInlinePragma)
  Future<List<TransportOutboundPayload>> readChunks(int count) => _client.readChunks(count);

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await read().then(listener, onError: onError);
    }
  }

  void listenChunked(int count, void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await readChunks(count).then((chunks) => chunks.forEach(listener), onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes, {TransportRetryConfiguration? retry}) => retry == null
      ? _client.write(bytes)
      : retry.options.retry(
          () => _client.write(bytes),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  Future<void> close() => _client.close();
}

class TransportClientDatagramCommunicator {
  final TransportClient _client;

  TransportClientDatagramCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> receiveMessage({int? flags}) => _client.receiveMessageFlush(flags: flags);

  @pragma(preferInlinePragma)
  Future<List<TransportOutboundPayload>> receiveMessageChunks(int count, {int? flags}) => _client.receiveMessageChunks(count, flags: flags);

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveMessage().then(listener, onError: onError);
    }
  }

  void listenChunked(int count, void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveMessageChunks(count).then((chunks) => chunks.forEach(listener), onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags, TransportRetryConfiguration? retry}) => retry == null
      ? _client.sendMessage(bytes, flags: flags)
      : retry.options.retry(
          () => _client.sendMessage(bytes, flags: flags),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> close() => _client.close();
}

class TransportServerConnection {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerConnection(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportInboundStreamPayload> read() => _server.readFlush(_channel);

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => _server.writeFlush(bytes, _channel);

  void listen(void Function(TransportInboundStreamPayload paylad) listener, {void Function(dynamic error, StackTrace? stackTrace)? onError}) async {
    while (!_server.closing && _server.connectionIsActive(_channel.fd)) {
      await read().then(listener, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
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
  Future<TransportInboundDatagramPayload> receiveMessage({int? flags}) => _server.receiveMessageFlush(_channel, flags: flags);

  void listen(
    void Function(TransportInboundDatagramPayload payload) listener, {
    void Function(Exception error, StackTrace stackTrace)? onError,
    int? flags,
  }) async {
    while (!_server.closing) {
      await receiveMessage(flags: flags).then(listener, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error, stackTrace);
      });
    }
  }

  @pragma(preferInlinePragma)
  Future<void> close() => _server.close();
}

class TransportServerDatagramSender {
  final TransportServer _server;
  final TransportChannel _channel;
  final TransportBuffers _buffers;
  final int _initialBufferId;
  final Uint8List initialPayload;

  TransportServerDatagramSender(this._server, this._channel, this._buffers, this._initialBufferId, this.initialPayload);

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _server.sendMessageFlush(bytes, _initialBufferId, _channel, flags: flags);

  @pragma(preferInlinePragma)
  void release() => _buffers.release(_initialBufferId);
}
