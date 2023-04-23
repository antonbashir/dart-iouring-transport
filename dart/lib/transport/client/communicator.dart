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
  Future<TransportPayload> readSingle({bool submit = true}) => _client.readSingle(submit: submit);

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> readMany(int count, {bool submit = true}) => _client.readMany(count);

  void listenBySingle(void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await readSingle().then(listener, onError: onError);
    }
  }

  void listeByMany(int count, void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await readMany(count).then((chunks) => chunks.forEach(listener), onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes, {TransportRetryConfiguration? retry}) => retry == null
      ? _client.writeSingle(bytes)
      : retry.options.retry(
          () => _client.writeSingle(bytes),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes, {TransportRetryConfiguration? retry}) => retry == null
      ? _client.writeMany(bytes)
      : retry.options.retry(
          () => _client.writeMany(bytes),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  Future<void> close() => _client.close();
}

class TransportClientDatagramCommunicator {
  final TransportClient _client;

  TransportClientDatagramCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportPayload> receiveSingleMessage({int? flags}) => _client.receiveSingleMessage(flags: flags);

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> receiveManyMessages(int count, {int? flags}) => _client.receiveManyMessage(count, flags: flags);

  void listenBySingle(void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveSingleMessage().then(listener, onError: onError);
    }
  }

  void listenByMany(int count, void Function(TransportPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveManyMessages(count).then((chunks) => chunks.forEach(listener), onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> sendSingleMessage(Uint8List bytes, {int? flags, TransportRetryConfiguration? retry}) => retry == null
      ? _client.sendSingleMessage(bytes, flags: flags)
      : retry.options.retry(
          () => _client.sendSingleMessage(bytes, flags: flags),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> sendManyMessages(List<Uint8List> bytes, {int? flags, TransportRetryConfiguration? retry}) => retry == null
      ? _client.sendManyMessages(bytes, flags: flags)
      : retry.options.retry(
          () => _client.sendManyMessages(bytes, flags: flags),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> close() => _client.close();
}
