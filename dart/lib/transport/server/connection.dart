import 'dart:typed_data';

import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerConnection(this._server, this._channel);

  @pragma(preferInlinePragma)
  Future<TransportPayload> readSingle({bool submit = false}) => _server.readSingle(_channel);

  @pragma(preferInlinePragma)
  Future<List<TransportPayload>> readMany(int count) => _server.readMany(_channel, count);

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes) => _server.writeSingle(_channel, bytes);

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes) => _server.writeMany(_channel, bytes);

  void listenBySingle(void Function(TransportPayload payload) listener, {void Function(dynamic error, StackTrace? stackTrace)? onError}) async {
    while (!_server.closing && _server.connectionIsActive(_channel.fd)) {
      await readSingle().then(listener, onError: (error, stackTrace) {
        if (error is TransportClosedException) return;
        if (error is TransportZeroDataException) return;
        if (error is TransportInternalException && (transportRetryableErrorCodes.contains(error.code))) return;
        onError?.call(error, stackTrace);
      });
    }
  }

  void listenByMany(int count, void Function(TransportPayload payload) listener, {void Function(dynamic error, StackTrace? stackTrace)? onError}) async {
    while (!_server.closing && _server.connectionIsActive(_channel.fd)) {
      await readMany(count).then((fragments) => fragments.forEach(listener), onError: (error, stackTrace) {
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
