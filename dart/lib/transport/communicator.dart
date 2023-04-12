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

class TransportClientCommunicator {
  final TransportClient _client;

  TransportClientCommunicator(this._client);

  Future<TransportOutboundPayload> read() => _client.read();

  Future<void> write(Uint8List bytes) => _client.write(bytes);

  Future<TransportOutboundPayload> receiveMessage({int? flags}) => _client.receiveMessage(flags: flags);

  Future<void> sendMessage(Uint8List bytes, {int? flags}) => _client.sendMessage(bytes, flags: flags);

  Future<void> close() => _client.close();
}

class TransportServerStreamCommunicator {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerStreamCommunicator(this._server, this._channel);

  Future<TransportInboundStreamPayload> read() async {
    final bufferId = await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.eventStates.setInboundRead(bufferId, completer);
    _channel.read(bufferId, _server.readTimeout, offset: 0);
    return completer.future.then(
      (_) => TransportInboundStreamPayload(
        _server.readBuffer(bufferId),
        () => _server.releaseBuffer(bufferId),
        (bytes) {
          if (!_server.active) throw TransportClosedException.forServer();
          _server.reuseBuffer(bufferId);
          final completer = Completer<void>();
          _server.eventStates.setInboundWrite(bufferId, completer);
          _channel.write(bytes, bufferId, _server.writeTimeout);
          return completer.future;
        },
      ),
    );
  }

  Future<void> write(Uint8List bytes) async {
    final bufferId = await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.eventStates.setInboundWrite(bufferId, completer);
    _channel.write(bytes, bufferId, _server.writeTimeout);
    return completer.future;
  }

  Future<void> writeStream(Stream<Uint8List> stream) async => Future.wait(await stream.map((event) => write(event)).toList());

  Stream<TransportInboundStreamPayload> readStream() async* {
    while (_server.active) {
      yield await read();
    }
  }

  Future<void> close() => _server.close();
}

class TransportServerDatagramCommunicator {
  final TransportServer _server;
  final TransportChannel _channel;

  TransportServerDatagramCommunicator(this._server, this._channel);

  Future<TransportInboundDatagramPayload> receiveMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.eventStates.setInboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, _server.pointer.ref.family, _server.readTimeout, flags);
    return completer.future.then(
      (_) => TransportInboundDatagramPayload(
        _server.readBuffer(bufferId),
        () => _server.releaseBuffer(bufferId),
        (bytes, flags) {
          if (!_server.active) throw TransportClosedException.forServer();
          _server.reuseBuffer(bufferId);
          final completer = Completer<void>();
          _server.eventStates.setInboundWrite(bufferId, completer);
          _channel.respondMessage(bytes, bufferId, _server.pointer.ref.family, _server.writeTimeout, flags);
          return completer.future;
        },
      ),
    );
  }

  Future<TransportInboundDatagramEndpoint> receiveEndpoint({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = await _channel.allocate();
    if (!_server.active) throw TransportClosedException.forServer();
    final completer = Completer<void>();
    _server.eventStates.setInboundRead(bufferId, completer);
    _channel.receiveMessage(bufferId, _server.pointer.ref.family, _server.readTimeout, flags);
    return completer.future.then((_) => TransportInboundDatagramEndpoint(_server, _channel, _server.getDatagramEndpointAddress(bufferId), bufferId, _server.readBuffer(bufferId)));
  }

  Stream<TransportInboundDatagramPayload> receiveStream({int? flags}) async* {
    while (_server.active) {
      yield await receiveMessage(flags: flags);
    }
  }

  Future<void> close() => _server.close();
}

class TransportInboundDatagramEndpoint {
  final TransportServer _server;
  final TransportChannel _channel;
  final Pointer<sockaddr> _address;
  final int _initialBufferId;
  final Uint8List initialBytes;

  TransportInboundDatagramEndpoint(this._server, this._channel, this._address, this._initialBufferId, this.initialBytes);

  Future<void> send(Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    if (!_server.active) throw TransportClosedException.forServer();
    final bufferId = await _channel.allocate();
    final completer = Completer<void>();
    _server.eventStates.setInboundWrite(bufferId, completer);
    _channel.sendMessage(bytes, bufferId, _server.pointer.ref.family, _address, _server.writeTimeout, flags);
    return completer.future;
  }

  Future<void> sendStream(Stream<Uint8List> stream, {int? flags}) async => Future.wait(await stream.map((event) => send(event, flags: flags)).toList());

  void release() => _server.releaseBuffer(_initialBufferId);
}
