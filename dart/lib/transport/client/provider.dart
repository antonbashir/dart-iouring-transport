import 'dart:async';
import 'dart:typed_data';

import '../configuration.dart';
import '../constants.dart';
import '../payload.dart';
import 'client.dart';

class TransportClientStreamProvider {
  final TransportClient _client;

  const TransportClientStreamProvider(this._client);

  bool get active => !_client.closing;

  Stream<TransportPayload> get inbound => _client.inbound;

  Stream<void> get outbound => _client.outbound;

  @pragma(preferInlinePragma)
  void read(void Function(TransportClientStreamProvider client, Stream<TransportPayload> stream) handler) {
    unawaited(_client.read());
    handler(this, _client.inbound.map((event) {
      unawaited(_client.read());
      return event;
    }));
  }

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes) => _client.writeSingle(bytes);

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes) => _client.writeMany(bytes);

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}

class TransportClientDatagramProvider {
  final TransportClient _client;

  const TransportClientDatagramProvider(this._client);

  Stream<TransportPayload> get inbound => _client.inbound;

  Stream<void> get outbound => _client.outbound;

  @pragma(preferInlinePragma)
  Stream<TransportPayload> receiveBySingle() {
    unawaited(_client.receiveSingleMessage());
    return _client.inbound.map((event) {
      unawaited(_client.receiveSingleMessage());
      return event;
    });
  }

  @pragma(preferInlinePragma)
  Stream<TransportPayload> receiveByMany(int count) {
    unawaited(_client.receiveManyMessages(count));
    return _client.inbound.map((event) {
      unawaited(_client.receiveManyMessages(count));
      return event;
    });
  }

  @pragma(preferInlinePragma)
  Future<void> sendSingleMessage(Uint8List bytes, {TransportRetryConfiguration? retry, int? flags}) => _client.sendSingleMessage(bytes, flags: flags);

  @pragma(preferInlinePragma)
  Future<void> sendManyMessages(List<Uint8List> bytes, {TransportRetryConfiguration? retry, int? flags}) => _client.sendManyMessages(bytes, flags: flags);

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}
