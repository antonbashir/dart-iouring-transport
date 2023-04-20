import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'configuration.dart';
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
  Future<TransportOutboundPayload> read() => _client.readFlush();

  Stream<TransportOutboundPayload> readFragments({int count = 1}) async* {
    final controller = StreamController<TransportOutboundPayload>();
    yield* controller.stream;
    for (var i = 0; i < count - 1; i++) {
      if (_client.buffers.available()) {
        _client.read().then(controller.add, onError: controller.addError);
        continue;
      }
      try {
        yield await _client.readFlush();
      } finally {
        controller.close();
      }
    }
    try {
      yield await _client.readFlush();
    } finally {
      controller.close();
    }
  }

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await read().then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes, {TransportRetryConfiguration? retry}) => retry == null
      ? _client.writeFlush(bytes)
      : retry.options.retry(
          () => _client.writeFlush(bytes),
          retryIf: retry.predicate,
          onRetry: retry.onRetry,
        );

  Future<void> writeFragments(Iterable<Uint8List> bytes, {TransportRetryConfiguration? retry}) async {
    final iterator = HasNextIterator(bytes.iterator);
    while (true) {
      if (iterator.hasNext) {
        final next = iterator.next();
        if (iterator.hasNext) {
          await _writeFragment(next);
          continue;
        }
        await _client.writeFlush(next);
        break;
      }
    }
  }

  @pragma(preferInlinePragma)
  Future<void> _writeFragment(Uint8List bytes) async {
    if (bytes.length <= _client.buffers.bufferSize) {
      if (!_client.buffers.available()) {
        return await _client.writeFlush(bytes);
      }
      _client.write(bytes);
      return;
    }
    do {
      var offset = 0;
      var limit = min(bytes.length, _client.buffers.bufferSize);
      bytes = bytes.sublist(offset, limit);
      if (!_client.buffers.available()) {
        await _client.writeFlush(bytes);
      }
      _client.write(bytes);
      offset += limit;
    } while (bytes.isNotEmpty);
  }

  Future<void> close() => _client.close();
}

class TransportClientDatagramCommunicator {
  final TransportClient _client;

  TransportClientDatagramCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> receiveMessage({int? flags}) => _client.receiveMessageFlush(flags: flags);

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (!_client.closing) {
      await receiveMessage().then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags, TransportRetryConfiguration? retry}) => retry == null
      ? _client.sendMessageFlush(bytes, flags: flags)
      : retry.options.retry(
          () => _client.sendMessageFlush(bytes, flags: flags),
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

main() {
  _func().listen((event) => print(event.toString()), onError: (err) => print(err));
}

Stream<bool> _func() async* {
  final okCompleter = Completer<bool>();
  okCompleter.complete(true);
  yield* okCompleter.future.asStream();

  final notOkCompleter = Completer<bool>();
  notOkCompleter.completeError(Exception());
  yield* notOkCompleter.future.asStream();

  print("after exception");
}
