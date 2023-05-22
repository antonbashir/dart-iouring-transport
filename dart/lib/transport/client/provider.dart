import 'dart:async';
import 'dart:typed_data';

import '../configuration.dart';
import '../constants.dart';
import '../payload.dart';
import 'client.dart';

class TransportClientConnection {
  final TransportClientChannel _client;

  const TransportClientConnection(this._client);

  bool get active => _client.active;
  Stream<TransportPayload> get inbound => _client.inbound;

  @pragma(preferInlinePragma)
  Stream<TransportPayload> read() {
    unawaited(_client.read());
    return _client.inbound.map((event) {
      if (_client.active) unawaited(_client.read());
      return event;
    });
  }

  @pragma(preferInlinePragma)
  void writeSingle(Uint8List bytes) => unawaited(_client.writeSingle(bytes));

  @pragma(preferInlinePragma)
  void writeMany(List<Uint8List> bytes) => unawaited(_client.writeMany(bytes));

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}

class TransportDatagramClient {
  final TransportClientChannel _client;

  const TransportDatagramClient(this._client);

  bool get active => _client.active;
  Stream<TransportPayload> get inbound => _client.inbound;

  @pragma(preferInlinePragma)
  Stream<TransportPayload> receiveBySingle() {
    unawaited(_client.receiveSingleMessage());
    return _client.inbound.map((event) {
      if (_client.active) unawaited(_client.receiveSingleMessage());
      return event;
    });
  }

  @pragma(preferInlinePragma)
  Stream<TransportPayload> receiveByMany(int count) {
    unawaited(_client.receiveManyMessages(count));
    return _client.inbound.map((event) {
      if (_client.active) unawaited(_client.receiveManyMessages(count));
      return event;
    });
  }

  @pragma(preferInlinePragma)
  void sendSingleMessage(Uint8List bytes, {TransportRetryConfiguration? retry, int? flags}) => unawaited(_client.sendSingleMessage(bytes, flags: flags));

  @pragma(preferInlinePragma)
  void sendManyMessages(List<Uint8List> bytes, {TransportRetryConfiguration? retry, int? flags}) => unawaited(_client.sendManyMessages(bytes, flags: flags));

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}
