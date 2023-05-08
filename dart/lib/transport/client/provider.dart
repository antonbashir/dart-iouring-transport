import 'dart:async';
import 'dart:typed_data';

import '../configuration.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'client.dart';

class TransportClientStreamProvider {
  final TransportClient _client;

  const TransportClientStreamProvider(this._client);

  bool get active => !_client.closing;

  @pragma(preferInlinePragma)
  Future<TransportPayload> read({bool submit = true}) => _client.read(submit: submit);

  void listen(void Function(TransportPayload paylad, void Function() canceler) listener, {void Function(Object error)? onError}) async {
    var canceled = false;
    while (!_client.closing && !canceled) {
      await read().then((value) => listener(value, () => canceled = true), onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error);
      });
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
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}

class TransportClientDatagramProvider {
  final TransportClient _client;

  const TransportClientDatagramProvider(this._client);

  @pragma(preferInlinePragma)
  Future<TransportPayload> receiveSingleMessage({TransportRetryConfiguration? retry, bool submit = true, int? flags}) => retry == null
      ? _client.receiveSingleMessage(flags: flags, submit: submit)
      : retry.options.retry(
          () => _client.receiveSingleMessage(flags: flags, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> receiveManyMessages(int count, {TransportRetryConfiguration? retry, bool submit = true, int? flags}) => retry == null
      ? _client.receiveManyMessage(count, flags: flags, submit: submit)
      : retry.options.retry(
          () => _client.receiveManyMessage(count, flags: flags, submit: submit),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  void listenBySingle(void Function(TransportPayload paylad) listener, {void Function(Object error)? onError}) async {
    while (!_client.closing) {
      await receiveSingleMessage().then(listener, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error);
      });
    }
  }

  void listenByMany(int count, void Function(TransportPayload paylad) listener, {void Function(Object error)? onError}) async {
    while (!_client.closing) {
      await receiveManyMessages(count).then((fragments) => fragments.forEach(listener), onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error);
      });
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
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}
