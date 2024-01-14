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

  @pragma(preferInlinePragma)
  Future<void> read() => _connection.read();

  @pragma(preferInlinePragma)
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

  @pragma(preferInlinePragma)
  void writeSingle(Uint8List bytes, {void Function(Exception error)? onError, void Function()? onDone}) {
    unawaited(_connection.writeSingle(bytes, onError: onError, onDone: onDone).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  void writeMany(List<Uint8List> bytes, {bool linked = true, void Function(Exception error)? onError, void Function()? onDone}) {
    var doneCounter = 0;
    var errorCounter = 0;
    unawaited(_connection.writeMany(bytes, linked: linked, onError: (error) {
      if (++errorCounter + doneCounter == bytes.length) onError?.call(error);
    }, onDone: () {
      if (errorCounter == 0 && ++doneCounter == bytes.length) onDone?.call();
    }).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulTimeout}) => _connection.close(gracefulTimeout: gracefulTimeout);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulTimeout}) => _connection.closeServer(gracefulTimeout: gracefulTimeout);
}

class TransportServerDatagramReceiver {
  final TransportServerChannel _server;

  const TransportServerDatagramReceiver(this._server);

  Stream<TransportServerDatagramResponder> get inbound => _server.inbound;
  bool get active => _server.active;

  @pragma(preferInlinePragma)
  Stream<TransportServerDatagramResponder> stream({int? flags}) {
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
  Future<void> closeServer({Duration? gracefulTimeout}) => _server.close(gracefulTimeout: gracefulTimeout);
}
