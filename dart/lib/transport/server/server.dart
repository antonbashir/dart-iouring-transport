import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'provider.dart';
import 'registry.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';

abstract class TransportServer {
  Future<void> close({Duration? gracefulDuration});
}

class TransportServerConnectionChannel {
  final _closer = Completer();
  final StreamController<TransportPayload> _inboundEvents = StreamController();
  final _outboundHandlers = <int, void Function()>{};
  final _outboundErrorHandlers = <int, void Function(Exception error)>{};
  final int _readTimeout;
  final int _writeTimeout;
  final TransportChannel channel;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final TransportServerChannel _server;
  final TransportBuffers _buffers;
  final TransportPayloadPool _payloadPool;
  final int _fd;

  var _active = true;
  var _closing = false;
  var _pending = 0;

  bool get active => !closing;
  Stream<TransportPayload> get inbound => _inboundEvents.stream;
  bool get closing => _closing;

  TransportServerConnectionChannel(
    this._server,
    this._buffers,
    this._bindings,
    this._fd,
    this._payloadPool,
    this._readTimeout,
    this._writeTimeout,
    this.channel,
    this._workerPointer,
  );

  Future<void> read() async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing || _server._closing) return Future.error(TransportClosedException.forServer());
    channel.read(bufferId, _readTimeout, transportEventRead | transportEventServer);
    _pending++;
  }

  Future<void> writeSingle(Uint8List bytes, {void Function(Exception error)? onError, void Function()? onDone}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing || _server._closing) return Future.error(TransportClosedException.forServer());
    if (onError != null) _outboundErrorHandlers[bufferId] = onError;
    if (onDone != null) _outboundHandlers[bufferId] = onDone;
    channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    _pending++;
  }

  Future<void> writeMany(List<Uint8List> bytes, {void Function(Exception error)? onError, void Function()? onDone}) async {
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing || _server._closing) return Future.error(TransportClosedException.forServer());
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      channel.write(
        bytes[index],
        bufferId,
        _writeTimeout,
        transportEventWrite | transportEventServer,
        sqeFlags: transportIosqeIoLink,
      );
      if (onError != null) _outboundErrorHandlers[bufferId] = onError;
      if (onDone != null) _outboundHandlers[bufferId] = onDone;
    }
    channel.write(
      bytes.last,
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventServer,
    );
    if (onError != null) _outboundErrorHandlers[lastBufferId] = onError;
    if (onDone != null) _outboundHandlers[lastBufferId] = onDone;
    _pending += bytes.length;
  }

  void notify(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (event == transportEventRead) {
        if (result > 0) {
          _buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
          return;
        }
        _buffers.release(bufferId);
        if (result == 0) {
          unawaited(close());
          return;
        }
        _inboundEvents.addError(createTransportException(TransportEvent.serverEvent(event), result, _bindings));
        unawaited(close());
        return;
      }
      _buffers.release(bufferId);
      if (result > 0) {
        final handler = _outboundHandlers.remove(bufferId);
        handler?.call();
        return;
      }
      if (result == 0) {
        unawaited(close());
        return;
      }
      final handler = _outboundErrorHandlers.remove(bufferId);
      handler?.call(createTransportException(TransportEvent.serverEvent(event), result, _bindings));
      unawaited(close());
      return;
    }
    _buffers.release(bufferId);
    if (_pending == 0) _closer.complete();
  }

  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, _fd);
    if (_pending > 0) await _closer.future;
    if (_inboundEvents.hasListener) await _inboundEvents.close();
    _server._removeConnection(_fd);
    _bindings.transport_close_descritor(_fd);
  }

  Future<void> closeServer({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}

class TransportServerChannel implements TransportServer {
  final _closer = Completer();
  final _connections = <int, TransportServerConnectionChannel>{};
  final StreamController<TransportDatagramResponder> _inboundEvents = StreamController();
  final _outboundHandlers = <int, void Function(Exception error)>{};

  final TransportChannel? _datagramChannel;
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportBuffers _buffers;
  final TransportServerRegistry _registry;
  final TransportPayloadPool _payloadPool;

  late void Function(TransportServerConnection connection) _acceptor;

  var _pending = 0;
  var _active = true;
  var _closing = false;

  bool get active => !_closing;
  Stream<TransportDatagramResponder> get inbound => _inboundEvents.stream;

  TransportServerChannel(
    this.pointer,
    this._workerPointer,
    this._bindings,
    this._readTimeout,
    this._writeTimeout,
    this._buffers,
    this._registry,
    this._payloadPool,
    this._datagramChannel,
  );

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection connection) onAccept) {
    if (_closing) throw TransportClosedException.forServer();
    _acceptor = onAccept;
    _bindings.transport_worker_accept(_workerPointer, pointer);
  }

  Future<void> receive({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) return Future.error(TransportClosedException.forServer());
    _datagramChannel!.receiveMessage(
      bufferId,
      pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventServer,
    );
    _pending++;
  }

  Future<void> respond(TransportChannel channel, Pointer<sockaddr> destination, Uint8List bytes, {int? flags, void Function(Exception error)? onError}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) return Future.error(TransportClosedException.forServer());
    if (onError != null) _outboundHandlers[bufferId] = onError;
    channel.sendMessage(
      bytes,
      bufferId,
      pointer.ref.family,
      destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventServer,
    );
    _pending++;
  }

  void notifyDatagram(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (event == transportEventReceiveMessage) {
        if (result > 0) {
          _buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getDatagramResponder(
            bufferId,
            _buffers.read(bufferId),
            this,
            _datagramChannel!,
            _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId),
          ));
          return;
        }
        _buffers.release(bufferId);
        _inboundEvents.addError(createTransportException(TransportEvent.serverEvent(event), result, _bindings));
        return;
      }
      _buffers.release(bufferId);
      if (result > 0) return;
      final handler = _outboundHandlers.remove(bufferId);
      handler?.call(createTransportException(TransportEvent.serverEvent(event), result, _bindings));
      return;
    }
    _buffers.release(bufferId);
    if (_pending == 0) _closer.complete();
  }

  @pragma(preferInlinePragma)
  void notifyAccept(int fd) {
    if (_closing) return;
    if (fd > 0) {
      final channel = TransportChannel(_workerPointer, fd, _bindings, _buffers);
      final connection = TransportServerConnectionChannel(
        this,
        _buffers,
        _bindings,
        fd,
        _payloadPool,
        _readTimeout,
        _writeTimeout,
        channel,
        _workerPointer,
      );
      _registry.addConnection(fd, connection);
      _connections[fd] = connection;
      _acceptor(TransportServerConnection(connection));
    }
    _bindings.transport_worker_accept(_workerPointer, pointer);
  }

  @pragma(preferInlinePragma)
  bool connectionIsActive(int fd) => _connections[fd]?._closing == false;

  @pragma(preferInlinePragma)
  void _removeConnection(int fd) {
    _connections.remove(fd);
    _registry.removeConnection(fd);
  }

  @override
  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    await Future.wait(_connections.values.toList().map((connection) => connection.close(gracefulDuration: gracefulDuration)));
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, pointer.ref.fd);
    if (_pending > 0) await _closer.future;
    if (_inboundEvents.hasListener) await _inboundEvents.close();
    _registry.removeServer(pointer.ref.fd);
    _bindings.transport_close_descritor(pointer.ref.fd);
    _bindings.transport_server_destroy(pointer);
  }
}
