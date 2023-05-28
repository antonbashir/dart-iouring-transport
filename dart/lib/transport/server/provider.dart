import 'dart:async';
import 'dart:typed_data';

import '../configuration.dart';
import '../constants.dart';
import '../payload.dart';
import 'server.dart';

class TransportServerConnection {
  final TransportServerConnectionChannel _connection;

  const TransportServerConnection(this._connection);

  Stream<TransportPayload> get inbound => _connection.inbound;
  bool get active => _connection.active;

  Stream<TransportPayload> read() {
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

  void writeSingle(Uint8List bytes, {TransportRetryConfiguration? retry, void Function(Exception error)? onError, void Function()? onDone}) {
    if (retry == null) {
      unawaited(_connection.writeSingle(bytes, onError: onError, onDone: onDone));
      return;
    }

    var attempt = 0;
    void _onError(Exception error) {
      if (!retry.predicate(error)) {
        onError?.call(error);
        return;
      }
      if (++attempt == retry.maxAttempts) {
        onError?.call(error);
        return;
      }
      unawaited(Future.delayed(retry.options.delay(attempt), () {
        unawaited(_connection.writeSingle(bytes, onError: _onError, onDone: onDone));
      }));
    }

    unawaited(_connection.writeSingle(bytes, onError: _onError, onDone: onDone));
  }

  void writeMany(List<Uint8List> bytes, {TransportRetryConfiguration? retry, void Function(Exception error)? onError, void Function()? onDone}) {
    if (retry == null) {
      var doneCounter = 0;
      unawaited(_connection.writeMany(bytes, onError: onError, onDone: () {
        if (++doneCounter == bytes.length) onDone?.call();
      }));
      return;
    }

    var doneCounter = 0;
    var errorCounter = 0;
    var attempt = 0;

    void _onError(Exception error) {
      if (++errorCounter + doneCounter == bytes.length) {
        errorCounter = 0;
        if (!retry.predicate(error)) {
          onError?.call(error);
          return;
        }
        if (++attempt == retry.maxAttempts) {
          onError?.call(error);
          return;
        }
        unawaited(Future.delayed(retry.options.delay(attempt), () {
          unawaited(_connection.writeMany(bytes.sublist(doneCounter), onError: _onError, onDone: () {
            if (++doneCounter == bytes.length) onDone?.call();
          }));
        }));
      }
    }

    unawaited(_connection.writeMany(bytes, onError: _onError, onDone: () {
      if (++doneCounter == bytes.length) onDone?.call();
    }));
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _connection.close(gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<void> closeServer({Duration? gracefulDuration}) => _connection.closeServer(gracefulDuration: gracefulDuration);
}

class TransportServerDatagramReceiver {
  final TransportServerChannel _server;

  const TransportServerDatagramReceiver(this._server);

  Stream<TransportDatagramResponder> get inbound => _server.inbound;
  bool get active => _server.active;

  Stream<TransportDatagramResponder> receive({int? flags}) {
    final out = StreamController<TransportDatagramResponder>(sync: true);
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
