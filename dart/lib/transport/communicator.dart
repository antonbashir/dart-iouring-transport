import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'bindings.dart';
import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'exception.dart';
import 'payload.dart';
import 'server.dart';

class TransportClientStreamCommunicator {
  final TransportClient _client;

  TransportClientStreamCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> read() => _client.read();

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (_client.active) {
      await read().then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> write(Uint8List bytes) => _client.write(bytes);

  Future<void> close() => _client.close();
}

class TransportClientDatagramCommunicator {
  final TransportClient _client;

  TransportClientDatagramCommunicator(this._client);

  @pragma(preferInlinePragma)
  Future<TransportOutboundPayload> receiveMessage({int? flags}) => _client.receiveMessage(flags: flags);

  void listen(void Function(TransportOutboundPayload paylad) listener, {void Function(Exception error)? onError}) async {
    while (_client.active) {
      await receiveMessage().then(listener, onError: onError);
    }
  }

  @pragma(preferInlinePragma)
  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _client.sendMessage(bytes, flags: flags);

  Future<void> close() => _client.close();
}

class TransportServerStreamCommunicator {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerStreamCommunicator(this._server, this._channel);

  Future<TransportInboundStreamPayload> read() async {
    final bufferId = _channel.getBuffer() ?? await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.callbacks.setInboundRead(bufferId, completer);
    _channel.read(bufferId, _server.readTimeout, transportEventRead);
    return completer.future.then(
      (_) => TransportInboundStreamPayload(
        _server.readBuffer(bufferId),
        () => _server.releaseBuffer(bufferId),
        (bytes) {
          if (!_server.active) throw TransportClosedException.forServer();
          _server.reuseBuffer(bufferId);
          final completer = Completer<void>();
          _server.callbacks.setInboundWrite(bufferId, completer);
          _channel.write(bytes, bufferId, _server.writeTimeout, transportEventWrite);
          return completer.future;
        },
      ),
    );
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = _channel.getBuffer() ?? await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.callbacks.setInboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, _server.writeTimeout, transportEventWrite);
    return completer.future;
  }

  void listen(void Function(TransportInboundStreamPayload paylad) listener, {void Function(dynamic error, StackTrace? stackTrace)? onError}) async {
    while (_server.active) {
      await read().then(listener, onError: onError);
    }
  }

  Future<void> close() => _server.close();
}

class TransportServerDatagramReceiver {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerDatagramReceiver(this._server, this._channel);

  Future<TransportInboundDatagramPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _channel.getBuffer() ?? await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.callbacks.setInboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, _server.pointer.ref.family, _server.readTimeout, flags, transportEventReceiveMessage);
    return completer.future.then(
      (_) => TransportInboundDatagramPayload(
        _server.readBuffer(bufferId),
        TransportInboundDatagramSender(_server, _channel, _server.getDatagramEndpointAddress(bufferId), bufferId, _server.readBuffer(bufferId)),
        () => _server.releaseBuffer(bufferId),
        (bytes, flags) {
          if (!_server.active) throw TransportClosedException.forServer();
          _server.reuseBuffer(bufferId);
          final completer = Completer<void>();
          _server.callbacks.setInboundWrite(bufferId, completer);
          _channel.respondMessage(bytes, bufferId, _server.pointer.ref.family, _server.writeTimeout, flags, transportEventSendMessage);
          return completer.future;
        },
      ),
    );
  }

  void listen(void Function(TransportInboundDatagramPayload payload) listener, {void Function(Exception error)? onError, int? flags}) async {
    while (_server.active) {
      await receiveMessage(flags: flags).then(listener, onError: onError);
    }
  }

  Future<void> close() => _server.close();
}

class TransportInboundDatagramSender {
  final TransportServer _server;
  final TransportChannel _channel;
  final Pointer<sockaddr> _address;
  final int _initialBufferId;
  final Uint8List initialPayload;

  TransportInboundDatagramSender(this._server, this._channel, this._address, this._initialBufferId, this.initialPayload);

  Future<void> sendMessage(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    if (!_server.active) throw TransportClosedException.forServer();
    final bufferId = _channel.getBuffer() ?? await _channel.allocate();
    final completer = Completer<void>();
    _server.callbacks.setInboundWrite(bufferId, completer);
    _channel.sendMessage(bytes, bufferId, _server.pointer.ref.family, _address, _server.writeTimeout, flags, transportEventSendMessage);
    return completer.future;
  }

  @pragma(preferInlinePragma)
  void release() => _server.releaseBuffer(_initialBufferId);
}
