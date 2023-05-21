import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/extensions.dart';

import '../links.dart';
import 'connection.dart';
import 'registry.dart';
import '../bindings.dart';
import '../buffers.dart';
import '../callbacks.dart';
import '../channel.dart';
import '../constants.dart';
import '../exception.dart';
import '../payload.dart';

class TransportServerInternalConnection {
  var active = true;
  var closing = false;
  var pending = 0;
  Completer<void> closer = Completer();

  final TransportBindings _bindings;
  final TransportServer _server;
  final TransportCallbacks _callbacks;
  final TransportBuffers _buffers;
  final int _fd;

  TransportServerInternalConnection(this._server, this._callbacks, this._buffers, this._bindings, this._fd);

  void notify(int bufferId, int result, int event) {
    pending--;
    if (active && _server.active) {
      if (result < 0) {
        unawaited(_server.closeConnection(_fd));
        if (result == -ECANCELED) {
          _callbacks.notifyDataError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
          return;
        }
        _callbacks.notifyDataError(
          bufferId,
          TransportInternalException(
            event: TransportEvent.ofEvent(event),
            code: result,
            message: result.kernelErrorToString(_bindings),
            bufferId: bufferId,
          ),
        );
        return;
      }
      if (result == 0) {
        unawaited(_server.closeConnection(_fd));
        _callbacks.notifyDataError(bufferId, TransportZeroDataException(event: TransportEvent.ofEvent(event)));
        return;
      }
      _buffers.setLength(bufferId, result);
      _callbacks.notifyData(bufferId);
      return;
    }
    _callbacks.notifyDataError(bufferId, TransportClosedException.forServer());
    if (!active && pending == 0) closer.complete();
  }
}

abstract class TransportServerCloser {
  Future<void> close({Duration? gracefulDuration});
}

class TransportServer implements TransportServerCloser {
  final _closer = Completer();
  final _connections = <int, TransportServerInternalConnection>{};

  final TransportChannel? _datagramChannel;
  final Pointer<transport_server_t> pointer;
  final Pointer<transport_worker_t> _workerPointer;
  final TransportBindings _bindings;
  final int _readTimeout;
  final int _writeTimeout;
  final TransportCallbacks _callbacks;
  final TransportLinks _links;
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
    this._callbacks,
    this._readTimeout,
    this._writeTimeout,
    this._buffers,
    this._registry,
    this._payloadPool,
    this._links,
    this._datagramChannel,
  );

  @pragma(preferInlinePragma)
  void accept(void Function(TransportServerConnection connection) onAccept) {
    if (_closing) throw TransportClosedException.forServer();
    _acceptor = onAccept;
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  Future<TransportPayload> read(TransportChannel channel, {bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    Completer<int>? completer = Completer<int>();
    _callbacks.setData(bufferId, completer);
    channel.read(bufferId, _readTimeout, transportEventRead | transportEventServer);
    connection.pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    final result = await completer.future.then(_handleSingleRead, onError: _handleSingleError);
    completer = null;
    return result;
  }

  Future<void> writeSingle(TransportChannel channel, Uint8List bytes, {bool submit = true}) async {
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    Completer<int>? completer = Completer<int>();
    _callbacks.setData(bufferId, completer);
    channel.write(bytes, bufferId, _writeTimeout, transportEventWrite | transportEventServer);
    connection.pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    final result = await completer.future.then(_handleSingleWrite, onError: _handleSingleError);
    completer = null;
    return result;
  }

  Future<void> writeMany(TransportChannel channel, List<Uint8List> bytes, {bool submit = true}) async {
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forServer();
    final connection = _connections[channel.fd];
    if (connection == null || connection.closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _links.set(bufferId, lastBufferId);
      channel.write(
        bytes[index],
        bufferId,
        _writeTimeout,
        transportEventWrite | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    final completer = Completer<int>();
    _links.set(lastBufferId, lastBufferId);
    _callbacks.setData(lastBufferId, completer);
    channel.write(
      bytes.last,
      lastBufferId,
      _writeTimeout,
      transportEventWrite | transportEventServer | transportEventLink,
    );
    connection.pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyWrite, onError: _handleManyError);
  }

  Future<TransportDatagramResponder> receiveSingleMessage({bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final completer = Completer<int>();
    _callbacks.setData(bufferId, completer);
    _datagramChannel!.receiveMessage(bufferId, pointer.ref.family, _readTimeout, flags, transportEventReceiveMessage | transportEventServer);
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleSingleReceive, onError: _handleSingleError);
  }

  Future<List<TransportDatagramResponder>> receiveManyMessages(int count, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(count);
    if (_closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < count - 1; index++) {
      final bufferId = bufferIds[index];
      _links.set(bufferId, lastBufferId);
      _datagramChannel!.receiveMessage(
        bufferId,
        pointer.ref.family,
        _readTimeout,
        flags,
        transportEventReceiveMessage | transportEventServer | transportEventLink,
        sqeFlags: transportIosqeIoLink,
      );
    }
    final completer = Completer<int>();
    _links.set(lastBufferId, lastBufferId);
    _callbacks.setData(lastBufferId, completer);
    _datagramChannel!.receiveMessage(
      lastBufferId,
      pointer.ref.family,
      _readTimeout,
      flags,
      transportEventReceiveMessage | transportEventServer | transportEventLink,
    );
    _pending++;
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyReceive, onError: _handleManyError);
  }

  Future<void> respondSingleMessage(TransportChannel channel, Pointer<sockaddr> destination, Uint8List bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    if (_closing) throw TransportClosedException.forServer();
    final completer = Completer<int>();
    _callbacks.setData(bufferId, completer);
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
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleSingleWrite, onError: _handleSingleError);
  }

  Future<void> respondManyMessages(TransportChannel channel, Pointer<sockaddr> destination, List<Uint8List> bytes, {bool submit = true, int? flags}) async {
    flags = flags ?? TransportDatagramMessageFlag.trunc.flag;
    final bufferIds = await _buffers.allocateArray(bytes.length);
    if (_closing) throw TransportClosedException.forServer();
    final lastBufferId = bufferIds.last;
    for (var index = 0; index < bytes.length - 1; index++) {
      final bufferId = bufferIds[index];
      _links.set(bufferId, lastBufferId);
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
    final completer = Completer<int>();
    _links.set(lastBufferId, lastBufferId);
    _callbacks.setData(lastBufferId, completer);
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
    if (submit) _bindings.transport_worker_submit(_workerPointer);
    return completer.future.then(_handleManyWrite, onError: _handleManyError);
  }

  void notifyDatagram(int bufferId, int result, int event) {
    _pending--;
    if (_active) {
      if (result < 0) {
        if (result == -ECANCELED) {
          _callbacks.notifyDataError(bufferId, TransportCanceledException(event: TransportEvent.ofEvent(event), bufferId: bufferId));
          return;
        }
        _callbacks.notifyDataError(
          bufferId,
          TransportInternalException(
            event: TransportEvent.ofEvent(event),
            code: result,
            message: result.kernelErrorToString(_bindings),
            bufferId: bufferId,
          ),
        );
        return;
      }
      if (result == 0) {
        _callbacks.notifyDataError(bufferId, TransportZeroDataException(event: TransportEvent.ofEvent(event)));
        return;
      }
      _buffers.setLength(bufferId, result);
      _callbacks.notifyData(bufferId);
      return;
    }
    _callbacks.notifyDataError(bufferId, TransportClosedException.forServer());
    if (_pending == 0 && _connections.isEmpty) _closer.complete();
  }

  @pragma(preferInlinePragma)
  void notifyAccept(int fd) {
    if (fd > 0) {
      final connection = TransportServerInternalConnection(this, _callbacks, _buffers, _bindings, fd);
      _registry.addConnection(fd, connection);
      _connections[fd] = connection;
      _acceptor(TransportServerConnection(this, TransportChannel(_workerPointer, fd, _bindings, _buffers)));
    }
    _bindings.transport_worker_accept(_workerPointer, pointer);
    _pending++;
  }

  @pragma(preferInlinePragma)
  bool connectionIsActive(int fd) => _connections[fd]?.closing == false;

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
    if (connection == null || connection.closing) return;
    connection.closing = false;
    if (gracefulDuration != null) await Future.delayed(gracefulDuration);
    connection.active = false;
    _bindings.transport_worker_cancel_by_fd(_workerPointer, fd);
    if (connection.pending > 0) await connection.closer.future;
    _registry.removeConnection(fd);
    _connections.remove(fd);
  }

  @pragma(preferInlinePragma)
  TransportPayload _handleSingleRead(int bufferId) => _payloadPool.getPayload(bufferId, _buffers.read(bufferId));

  @pragma(preferInlinePragma)
  TransportDatagramResponder _handleSingleReceive(int bufferId) => _payloadPool.getDatagramResponder(
        bufferId,
        _buffers.read(bufferId),
        this,
        _datagramChannel!,
        _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId),
      );

  @pragma(preferInlinePragma)
  List<TransportDatagramResponder> _handleManyReceive(int lastBufferId) => _links
      .select(lastBufferId)
      .map((bufferId) => _payloadPool.getDatagramResponder(
            bufferId,
            _buffers.read(bufferId),
            this,
            _datagramChannel!,
            _bindings.transport_worker_get_datagram_address(_workerPointer, pointer.ref.family, bufferId),
          ))
      .toList();

  @pragma(preferInlinePragma)
  void _handleSingleWrite(int bufferId) => _buffers.release(bufferId);

  @pragma(preferInlinePragma)
  void _handleManyWrite(int lastBufferId) => _buffers.releaseArray(_links.select(lastBufferId).toList());

  @pragma(preferInlinePragma)
  void _handleSingleError(error) {
    if (error is TransportExecutionException && error.bufferId != null) {
      _buffers.release(error.bufferId!);
    }
    throw error;
  }

  @pragma(preferInlinePragma)
  void _handleManyError(error) {
    if (error is TransportExecutionException && error.bufferId != null) {
      _buffers.releaseArray(_links.select(error.bufferId!).toList());
    }
    throw error;
  }
}
