import 'dart:async';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'responder.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServerConnectionChannel _connection;

  const TransportServerConnection(this._connection);

  Stream<TransportPayload> get inbound => _connection.inbound;
  bool get active => _connection.active;

  Future<void> read() => _connection.read();

  Stream<TransportPayload> stream() {
    final out = StreamController<TransportPayload>(sync: true);
    out.onListen = () => unawaited(_connection.read().onError((error, stackTrace) => out.addError(error!)));
    _connection.inbound.listen(
      (event) {
        out.add(event);
        if (_connection.active) unawaited(_connection.read().onError((error, stackTrace) => out.addError(error!)));
      },
      onDone: out.close,
      onError: out.addError,
    );
    return out.stream;
  }

  void writeSingle(Uint8List bytes, {void Function(Exception error)? onError, void Function()? onDone}) {
    unawaited(_connection.writeSingle(bytes, onError: onError, onDone: onDone).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  void writeMany(List<Uint8List> bytes, {void Function(Exception error)? onError, void Function()? onDone}) {
    var doneCounter = 0;
    unawaited(_connection.writeMany(bytes, onError: onError, onDone: () {
      if (++doneCounter == bytes.length) onDone?.call();
    }).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _connection.close(gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulDuration}) => _connection.closeServer(gracefulDuration: gracefulDuration);
}

class TransportServerDatagramReceiver {
  final TransportServerChannel _server;

  const TransportServerDatagramReceiver(this._server);

  Stream<TransportServerDatagramResponder> get inbound => _server.inbound;
  bool get active => _server.active;

  Stream<TransportServerDatagramResponder> receive({int? flags}) {
    final out = StreamController<TransportServerDatagramResponder>(sync: true);
    out.onListen = () => unawaited(_server.receive(flags: flags).onError((error, stackTrace) => out.addError(error!)));
    _server.inbound.listen(
      (event) {
        out.add(event);
        if (_server.active) unawaited(_server.receive(flags: flags).onError((error, stackTrace) => out.addError(error!)));
      },
      onDone: out.close,
      onError: (error) {
        out.addError(error);
        if (_server.active) unawaited(_server.receive(flags: flags).onError((error, stackTrace) => out.addError(error!)));
      },
    );
    return out.stream;
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}
