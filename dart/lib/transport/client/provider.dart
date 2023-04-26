import 'dart:async';
import 'dart:typed_data';

import '../configuration.dart';
import '../constants.dart';
import '../payload.dart';
import 'client.dart';

class TransportClientStreamProvider {
  final TransportClient _client;

  TransportClientStreamProvider(this._client);

  @pragma(preferInlinePragma)
  Future<TransportPayload> readSingle({bool submit = true}) => _client.readSingle(submit: submit);

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> readMany(int count, {bool submit = true}) => _client.readMany(count, submit: submit);

  void listenBySingle(void Function(TransportPayload paylad) listener, {void Function(Object error)? onError}) async {
    while (!_client.closing) {
      await readSingle().then(listener, onError: onError);
    }
  }

  void listeByMany(int count, void Function(TransportPayload paylad) listener, {void Function(Object error)? onError}) async {
    while (!_client.closing) {
      await readMany(count).then((chunks) => chunks.forEach(listener), onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes, {TransportRetryConfiguration? retry, bool submit = true}) => retry == null
      ? _client.writeSingle(bytes, submit: submit)
      : retry.options.retry(
          () => _client.writeSingle(bytes, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes, {TransportRetryConfiguration? retry, bool submit = true}) => retry == null
      ? _client.writeMany(bytes, submit: submit)
      : retry.options.retry(
          () => _client.writeMany(bytes, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> close() => _client.close();
}

class TransportClientDatagramProvider {
  final TransportClient _client;

  TransportClientDatagramProvider(this._client);

  @pragma(preferInlinePragma)
  Future<TransportPayload> receiveSingleMessage({bool submit = true, int? flags}) => _client.receiveSingleMessage(flags: flags, submit: submit);

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> receiveManyMessages(int count, {bool submit = true, int? flags}) => _client.receiveManyMessage(count, flags: flags, submit: submit);

  void listenBySingle(void Function(TransportPayload paylad) listener, {void Function(Object error)? onError}) async {
    while (!_client.closing) {
      await receiveSingleMessage().then(listener, onError: onError);
    }
  }

  void listenByMany(int count, void Function(TransportPayload paylad) listener, {void Function(Object error)? onError}) async {
    while (!_client.closing) {
      await receiveManyMessages(count).then((chunks) => chunks.forEach(listener), onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> sendSingleMessage(Uint8List bytes, {TransportRetryConfiguration? retry, bool submit = true, int? flags}) => retry == null
      ? _client.sendSingleMessage(bytes, flags: flags, submit: submit)
      : retry.options.retry(
          () => _client.sendSingleMessage(bytes, flags: flags, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> sendManyMessages(List<Uint8List> bytes, {TransportRetryConfiguration? retry, bool submit = true, int? flags}) => retry == null
      ? _client.sendManyMessages(bytes, flags: flags, submit: submit)
      : retry.options.retry(
          () => _client.sendManyMessages(bytes, flags: flags, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<void> close() => _client.close();
}
