import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'connection.dart';
import 'registry.dart';
import '../extensions.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';

class TransportServerInternalConnection {
  final _closer = Completer();
  final StreamController<TransportPayload> _inboundEvents = StreamController();
  final StreamController<void> _outboundEvents = StreamController();
  final int _readTimeout;
  final int _writeTimeout;
  final TransportChannel channel;

  var _active = true;
  var _closing = false;
  var _pending = 0;

  final TransportBindings _bindings;
  final TransportServer _server;
  final TransportBuffers _buffers;
  final TransportPayloadPool _payloadPool;
  final int _fd;

  TransportServerInternalConnection(
    this._server,
    this._buffers,
    this._bindings,
    this._fd,
    this._payloadPool,
    this._readTimeout,
    this._writeTimeout,
    this.channel,
  );

  Stream<TransportPayload> get inbound => _inboundEvents.stream;
  Stream<void> get outbound => _outboundEvents.stream;
  bool get closing => _closing;

  Future<void> read() async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing || _server._closing) throw TransportClosedException.forServer();
    channel.read(bufferId, _readTimeout, transportEventRead | transportEventServer);
    _pending++;
  }

  Future<void> writeSingle(Uint8List bytes) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing || _server._closing) throw TransportClosedException.forServer();
    channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    _pending++;
  }

  Future<void> writeMany(List<Uint8List> bytes) async {
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing || _server._closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      channel.write(
        bytes[index],
        bufferId,
        _writeTimeout,
        transportEventWrite | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    channel.write(
      bytes.last,
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventServer | transportEventLink,
    );
    _pending++;
  }

  void notify(int bufferId, int result, int event) {
    _pending--;
    if (_active && _server.active) {
      if (event.isReadEvent()) {
        if (result > 0) {
          _buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
          return;
        }
        unawaited(_server.closeConnection(_fd));
        _buffers.release(bufferId);
        _inboundEvents.addError(createTransportException(TransportEvent.ofEvent(event), result, _bindings));
        return;
      }
      if (result > 0) {
        _buffers.release(bufferId);
        return;
      }
      unawaited(_server.closeConnection(_fd));
      _outboundEvents.addError(createTransportException(
        TransportEvent.ofEvent(event),
        result,
        _bindings,
        payload: _payloadPool.getPayload(bufferId, _buffers.read(bufferId)),
      ));
      return;
    }
    _buffers.release(bufferId);
    event.isReadEvent() ? _inboundEvents.addError(TransportClosedException.forServer()) : _outboundEvents.addError(TransportClosedException.forServer());
    if (!_active && _pending == 0) _closer.complete();
  }

  Future<void> close({Duration? gracefulDuration}) => _server.closeConnection(_fd, gracefulDuration: gracefulDuration);

  Future<void> closeServer({Duration? gracefulDuration}) => _server.close(gracefulDuration: gracefulDuration);
}

abstract class TransportServerCloser {
  Future<void> close({Duration? gracefulDuration});
}

class TransportServer implements TransportServerCloser {
  final _closer = Completer();
  final _connections = <int, TransportServerInternalConnection>{};
  final StreamController<TransportPayload> _inboundEvents = StreamController();
  final StreamController<void> _outboundEvents = StreamController();

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
  bool get active => _active;
  var _closing = false;
  bool get closing => _closing;

  TransportServer(
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

  Stream<TransportPayload> get inbound => _inboundEvents.stream;
  Stream<void> get outbound => _outboundEvents.stream;

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection connection) onAccept) {
    if (_closing) throw TransportClosedException.forServer();
    _acceptor = onAccept;
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  Future<void> receiveSingleMessage({int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    _datagramChannel!.receiveMessage(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventServer);
    _pending++;
  }

  Future<void> receiveManyMessages(int count, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(count);
    if (_closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < count - 1; index++) {
      final bufferId = bufferIds[index];
      _datagramChannel!.receiveMessage(
        bufferId,
        pointer.ref.family,
        _readTimeout,
        flags,
        transportEventReceiveMessage | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    _datagramChannel!.receiveMessage(
      lastBufferId,
      pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventServer | transportEventLink,
    );
    _pending++;
  }

  Future<void> respondSingleMessage(TransportChannel channel, Pointer<sockaddr> destination, Uint8List bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
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

  Future<void> respondManyMessages(TransportChannel channel, Pointer<sockaddr> destination, List<Uint8List> bytes, {int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      channel.sendMessage(
        bytes[index],
        bufferId,
        pointer.ref.family,
        destination,
        _writeTimeout,
        flags,
        transportEventSendMessage | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    channel.sendMessage(
      bytes.last,
      lastBufferId,
      pointer.ref.family,
      destination,
      _writeTimeout,
      flags,
      transportEventSendMessage | transportEventServer | transportEventLink,
    );
    _pending++;
  }

  void notifyDatagram(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (event.isReadEvent()) {
        if (result > 0) {
          _buffers.setLength(bufferId, result);
          _inboundEvents.add(_payloadPool.getPayload(bufferId, _buffers.read(bufferId)));
          return;
        }
        _buffers.release(bufferId);
        _inboundEvents.addError(createTransportException(TransportEvent.ofEvent(event), result, _bindings));
        return;
      }
      if (result > 0) {
        _buffers.release(bufferId);
        return;
      }
      _outboundEvents.addError(createTransportException(
        TransportEvent.ofEvent(event),
        result,
        _bindings,
        payload: _payloadPool.getPayload(bufferId, _buffers.read(bufferId)),
      ));
      return;
    }
    _buffers.release(bufferId);
    event.isReadEvent() ? _inboundEvents.addError(TransportClosedException.forServer()) : _outboundEvents.addError(TransportClosedException.forServer());
    if (_pending == 0) _closer.complete();
  }

  @pragma(preferInlinePragma)
  void notifyAccept(int fd) {
    if (fd > 0) {
      final channel = TransportChannel(_workerPointer, fd, _bindings, _buffers);
      final connection = TransportServerInternalConnection(
        this,
        _buffers,
        _bindings,
        fd,
        _payloadPool,
        _readTimeout,
        _writeTimeout,
        channel,
      );
      _registry.addConnection(fd, connection);
      _connections[fd] = connection;
      _acceptor(TransportServerConnection(connection));
    }
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  @pragma(preferInlinePragma)
  bool connectionIsActive(int fd) => _connections[fd]?._closing == false;

  @override
  Future<void> close({Duration? gracefulDuration}) async {
    if (_closing) return;
    _closing = true;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    _active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, pointer.ref.fd);
    await Future.wait(_connections.keys.toList().map(closeConnection));
    if (_pending > 0) await _closer.future;
    _registry.removeServer(pointer.ref.fd);
    _bindings.transport_close_descritor(pointer.ref.fd);
    _bindings.transport_server_destroy(pointer);
  }

  Future<void> closeConnection(int fd, {Duration? gracefulDuration}) async {
    final connection = _connections[fd];
    if (connection == null || connection._closing) return;
    connection._closing = false;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    connection._active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, fd);
    if (connection._pending > 0) await connection._closer.future;
    _registry.removeConnection(fd);
    _connections.remove(fd);
  }
}
