import 'dart:async';
import 'dart:typed_data';

import '../configuration.dart';
import '../constants.dart';
import '../payload.dart';
import 'client.dart';

class TransportClientStreamCommunicator {
  final TransportClient _client;

  TransportClientStreamCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportPayload> read() => _client.read();

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> readBatch(int count) => _client.readBatch(count);

  void listen(void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await read().then(listener, onError: onError);
    }
  }

  void listeBatched(int count, void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await readBatch(count).then((chunks) => chunks.forEach(listener), onError: onError);
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
  Future<TransportPayload> receiveMessage({int? flags}) => _client.receiveMessage(flags: flags);

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> receiveMessageBatch(int count, {int? flags}) => _client.receiveMessageBatch(count, flags: flags);

  void listen(void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveMessage().then(listener, onError: onError);
    }
  }

  void listenBatched(int count, void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveMessageBatch(count).then((chunks) => chunks.forEach(listener), onError: onError);
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
