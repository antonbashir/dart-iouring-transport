import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';
import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/provider.dart';

import 'acceptor.dart';
import 'bindings.dart';
import 'channels.dart';
import 'constants.dart';
import 'lookup.dart';
import 'payload.dart';

class TransportEventLoopCallbacks {
  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <int, Completer<TransportPayload>>{};
  final _writeCallbacks = <int, Completer<void>>{};

  @pragma(preferInlinePragma)
  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;
  @pragma(preferInlinePragma)
  void putRead(int bufferId, Completer<TransportPayload> completer) => _readCallbacks[bufferId] = completer;
  @pragma(preferInlinePragma)
  void putWrite(int bufferId, Completer<void> completer) => _writeCallbacks[bufferId] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connectCallbacks.remove(fd)?.complete(client);
  @pragma(preferInlinePragma)
  void notifyRead(int bufferId, TransportPayload payload) => _readCallbacks.remove(bufferId)?.complete(payload);
  @pragma(preferInlinePragma)
  void notifyWrite(int bufferId) => _writeCallbacks.remove(bufferId)?.complete();

  void notifyConnectError(int fd, Exception error) => _connectCallbacks.remove(fd)?.completeError(error);
  void notifyReadError(int bufferId, Exception error) => _readCallbacks.remove(bufferId)?.completeError(error);
  void notifyWriteError(int bufferId, Exception error) => _writeCallbacks.remove(bufferId)?.completeError(error);

  bool isWaiting() => _connectCallbacks.isNotEmpty || _readCallbacks.isNotEmpty || _writeCallbacks.isNotEmpty;
}

class TransportEventLoop {
  final _callbacks = TransportEventLoopCallbacks();

  final SendPort _onExit;

  late final RawReceivePort onInbound;
  late final RawReceivePort onOutbound;

  final String? _libraryPath;
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;

  late final void Function(TransportServerChannel channel, int descriptor)? onAccept;
  late final FutureOr<Uint8List> Function(Uint8List input)? onInput;
  late final TransportProvider provider;

  bool serving = false;

  TransportEventLoop(
    this._libraryPath,
    this._bindings,
    this._transport,
    this._onExit,
  ) {
    provider = TransportProvider(
      () => TransportConnector(_callbacks, _bindings.transport_select_outbound_channel(_transport), _transport, _bindings),
      (path) => TransportFile(_callbacks, TransportResourceChannel(_bindings.transport_select_outbound_channel(_transport), _bindings), _bindings, path),
    );

    onInbound = RawReceivePort((List<dynamic> input) {
      for (var element in input) {
        _handleInbound(element[0], element[1], Pointer.fromAddress(element[2]));
      }
    });

    onOutbound = RawReceivePort((List<dynamic> input) {
      for (var element in input) {
        _handleOutbound(element[0], element[1], Pointer.fromAddress(element[2]));
      }
    });
  }

  Future<void> serve(
    String host,
    int port, {
    void Function(TransportServerChannel channel, int descriptor)? onAccept,
    FutureOr<Uint8List> Function(Uint8List input)? onInput,
  }) async {
    if (serving) return;

    serving = true;

    final fromAcceptor = ReceivePort();
    final acceptorExit = ReceivePort();

    Isolate.spawn<SendPort>((port) => TransportAcceptor(port).accept(), fromAcceptor.sendPort, onExit: acceptorExit.sendPort);

    fromAcceptor.listen((acceptorPort) {
      SendPort toAcceptor = acceptorPort as SendPort;
      toAcceptor.send([_libraryPath, _transport.address, host, port]);
    });

    await acceptorExit.first;
    acceptorExit.close();

    _onExit.send(null);
  }

  void _handleOutbound(int result, int userData, Pointer<transport_channel_t> channel) {
    if (result < 0) {
      if (userData & transportEventConnect != 0) {
        _bindings.transport_close_descritor(userData & ~transportEventAll);
        _callbacks.notifyConnectError(userData & ~transportEventAll, Exception("Connect exception with code $result"));
      }

      if (userData & transportEventReadCallback != 0 || userData & transportEventWriteCallback != 0) {
        final bufferId = userData & ~transportEventAll;
        final fd = channel.ref.used_buffers[bufferId];
        if (userData & transportEventReadCallback != 0) {
          if (result == -EAGAIN) {
            _bindings.transport_channel_read(channel, fd, bufferId, 0, transportEventReadCallback);
            return;
          }
          _bindings.transport_close_descritor(fd);
          channel.ref.used_buffers[bufferId] = transportBufferAvailable;
          _callbacks.notifyReadError(bufferId, Exception("Read exception with code $result"));
        }
        if (userData & transportEventWriteCallback != 0) {
          if (result == -EAGAIN) {
            _bindings.transport_channel_write(channel, fd, bufferId, 0, transportEventWriteCallback);
            return;
          }
          _bindings.transport_close_descritor(fd);
          channel.ref.used_buffers[bufferId] = transportBufferAvailable;
          _callbacks.notifyWriteError(bufferId, Exception("Write exception with code $result"));
        }
      }
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      final buffer = channel.ref.buffers[bufferId];
      _callbacks.notifyRead(bufferId, TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), () => channel.ref.used_buffers[bufferId] = transportBufferAvailable));
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      channel.ref.used_buffers[bufferId] = transportBufferAvailable;
      _callbacks.notifyWrite(bufferId);
      return;
    }

    if (userData & transportEventConnect != 0) {
      final fd = userData & ~transportEventAll;
      _callbacks.notifyConnect(fd, TransportClient(_callbacks, TransportResourceChannel(channel, _bindings), _bindings, fd));
      return;
    }
  }

  void _handleInbound(int result, int userData, Pointer<transport_channel_t> channel) {
    if (result & transportEventAwake != 0) {
      if (result < 0) {
        if (userData & transportEventRead != 0 || userData & transportEventWrite != 0) {
          final bufferId = userData & ~transportEventAll;
          final fd = channel.ref.used_buffers[bufferId];
          _bindings.transport_close_descritor(fd);
          channel.ref.used_buffers[bufferId] = transportBufferAvailable;
        }
        return;
      }

      if (userData & transportEventRead != 0) {
        final bufferId = userData & ~transportEventAll;
        final fd = channel.ref.used_buffers[bufferId];
        if (onInput == null) {
          channel.ref.used_buffers[bufferId] = transportBufferAvailable;
          return;
        }
        final buffer = channel.ref.buffers[bufferId];
        unawaited(Future.value(onInput!.call(buffer.iov_base.cast<Uint8>().asTypedList(result))).then((answer) {
          buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
          buffer.iov_len = answer.length;
          _bindings.transport_channel_write(channel, fd, bufferId, 0, transportEventWrite);
        }));
        return;
      }

      if (userData & transportEventWrite != 0) {
        final bufferId = userData & ~transportEventAll;
        final fd = channel.ref.used_buffers[bufferId];
        _bindings.transport_channel_read(channel, fd, bufferId, 0, transportEventRead);
        return;
      }

      if (userData & transportEventAccept != 0) {
        onAccept?.call(TransportServerChannel(channel, _bindings), result);
        return;
      }
    }
  }
}
