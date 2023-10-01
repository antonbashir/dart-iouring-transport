import 'dart:async';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'client.dart';

class TransportClientConnection {
  final TransportClientChannel _client;

  const TransportClientConnection(this._client);

  bool get active => _client.active;
  Stream<TransportPayload> get inbound => _client.inbound;

  Future<void> read() => _client.read();

  @pragma(preferInlinePragma)
  Stream<TransportPayload> stream() {
    final out = StreamController<TransportPayload>(sync: true);
    out.onListen = () => unawaited(_client.read().onError((error, stackTrace) => out.addError(error!)));
    _client.inbound.listen(
      (event) {
        out.add(event);
        if (_client.active) unawaited(_client.read().onError((error, stackTrace) => out.addError(error!)));
      },
      onDone: out.close,
      onError: out.addError,
    );
    return out.stream;
  }

  @pragma(preferInlinePragma)
  void writeSingle(Uint8List bytes, {void Function(Exception error)? onError, void Function()? onDone}) {
    unawaited(_client.writeSingle(bytes, onError: onError, onDone: onDone).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  void writeMany(List<Uint8List> bytes, {linked = true, void Function(Exception error)? onError, void Function()? onDone}) {
    var doneCounter = 0;
    var errorCounter = 0;
    unawaited(_client.writeMany(bytes, linked: linked, onError: (error) {
      if (++errorCounter + doneCounter == bytes.length) onError?.call(error);
    }, onDone: () {
      if (errorCounter == 0 && ++doneCounter == bytes.length) onDone?.call();
    }).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}

class TransportDatagramClient {
  final TransportClientChannel _client;

  const TransportDatagramClient(this._client);

  bool get active => _client.active;
  Stream<TransportPayload> get inbound => _client.inbound;

  @pragma(preferInlinePragma)
  Future<void> receive({int? flags}) => _client.receive(flags: flags);

  @pragma(preferInlinePragma)
  Stream<TransportPayload> stream({int? flags}) {
    final out = StreamController<TransportPayload>(sync: true);
    out.onListen = () => unawaited(_client.receive(flags: flags).onError((error, stackTrace) => out.addError(error!)));
    _client.inbound.listen(
      (event) {
        out.add(event);
        if (_client.active) unawaited(_client.receive(flags: flags).onError((error, stackTrace) => out.addError(error!)));
      },
      onDone: out.close,
      onError: (error) {
        out.addError(error);
        if (_client.active) unawaited(_client.receive(flags: flags).onError((error, stackTrace) => out.addError(error!)));
      },
    );
    return out.stream;
  }

  @pragma(preferInlinePragma)
  void sendSingle(
    Uint8List bytes, {
    int? flags,
    void Function(Exception error)? onError,
    void Function()? onDone,
  }) {
    unawaited(_client.sendSingle(bytes, onError: onError, onDone: onDone, flags: flags).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  void sendMany(
    List<Uint8List> bytes, {
    int? flags,
    bool linked = false,
    void Function(Exception error)? onError,
    void Function()? onDone,
  }) {
    var doneCounter = 0;
    var errorCounter = 0;
    unawaited(_client.sendMany(bytes, flags: flags, linked: linked, onError: (error) {
      if (++errorCounter + doneCounter == bytes.length) onError?.call(error);
    }, onDone: () {
      if (errorCounter == 0 && ++doneCounter == bytes.length) onDone?.call();
    }).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _client.close(gracefulDuration: gracefulDuration);
}
