import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:tuple/tuple.dart';

import 'acceptor.dart';
import 'bindings.dart';
import 'channels.dart';
import 'client.dart';
import 'constants.dart';
import 'file.dart';
import 'payload.dart';
import 'provider.dart';

class TransportEventLoopCallbacks {
  final _connectCallbacks = <int, Completer<TransportClient>>{};
  final _readCallbacks = <Tuple2<int, int>, Completer<TransportPayload>>{};
  final _writeCallbacks = <Tuple2<int, int>, Completer<void>>{};

  @pragma(preferInlinePragma)
  void putConnect(int fd, Completer<TransportClient> completer) => _connectCallbacks[fd] = completer;

  @pragma(preferInlinePragma)
  void putRead(Tuple2<int, int> key, Completer<TransportPayload> completer) => _readCallbacks[key] = completer;

  @pragma(preferInlinePragma)
  void putWrite(Tuple2<int, int> key, Completer<void> completer) => _writeCallbacks[key] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connectCallbacks.remove(fd)?.complete(client);

  @pragma(preferInlinePragma)
  void notifyRead(Tuple2<int, int> key, TransportPayload payload) => _readCallbacks.remove(key)?.complete(payload);

  @pragma(preferInlinePragma)
  void notifyWrite(Tuple2<int, int> key) => _writeCallbacks.remove(key)?.complete();

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connectCallbacks.remove(fd)?.completeError(error);

  @pragma(preferInlinePragma)
  void notifyReadError(Tuple2<int, int> key, Exception error) => _readCallbacks.remove(key)?.completeError(error);

  @pragma(preferInlinePragma)
  void notifyWriteError(Tuple2<int, int> key, Exception error) => _writeCallbacks.remove(key)?.completeError(error);
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
  late final TransportProvider provider;

  bool serving = false;

  final _inputStream = StreamController<TransportPayload>();

  final int _outboundPool;

  TransportEventLoop(
    this._libraryPath,
    this._bindings,
    this._transport,
    this._onExit,
    this._outboundPool,
  ) {
    final connector = TransportConnector(_callbacks, _transport, _bindings, _outboundPool);
    provider = TransportProvider(
      connector,
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

  Stream<TransportPayload> serve(
    String host,
    int port, {
    void Function(TransportServerChannel channel, int descriptor)? onAccept,
  }) {
    if (serving) return _inputStream.stream;

    this.onAccept = onAccept;

    serving = true;

    final fromAcceptor = ReceivePort();
    final acceptorExit = ReceivePort();

    Isolate.spawn<SendPort>((port) => TransportAcceptor(port).accept(), fromAcceptor.sendPort, onExit: acceptorExit.sendPort);

    fromAcceptor.listen((acceptorPort) {
      SendPort toAcceptor = acceptorPort as SendPort;
      toAcceptor.send([_libraryPath, _transport.address, host, port]);
    });

    return _inputStream.stream;
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
          _callbacks.notifyReadError(Tuple2(channel.address, bufferId), Exception("Read exception with code $result"));
        }
        if (userData & transportEventWriteCallback != 0) {
          if (result == -EAGAIN) {
            _bindings.transport_channel_write(channel, fd, bufferId, 0, transportEventWriteCallback);
            return;
          }
          _bindings.transport_close_descritor(fd);
          channel.ref.used_buffers[bufferId] = transportBufferAvailable;
          _callbacks.notifyWriteError(Tuple2(channel.address, bufferId), Exception("Write exception with code $result"));
        }
      }
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      final buffer = channel.ref.buffers[bufferId];
      _callbacks.notifyRead(
        Tuple2(channel.address, bufferId),
        TransportPayload(
          buffer.iov_base.cast<Uint8>().asTypedList(result),
          (_) => channel.ref.used_buffers[bufferId] = transportBufferAvailable,
        ),
      );
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final bufferId = userData & ~transportEventAll;
      channel.ref.used_buffers[bufferId] = transportBufferAvailable;
      _callbacks.notifyWrite(Tuple2(channel.address, bufferId));
      return;
    }

    if (userData & transportEventConnect != 0) {
      final fd = userData & ~transportEventAll;
      print("connect: $fd");
      _callbacks.notifyConnect(
        fd,
        TransportClient(_callbacks, TransportResourceChannel(channel, _bindings), _bindings, fd),
      );
      return;
    }
  }

  void _handleInbound(int result, int userData, Pointer<transport_channel_t> channel) {
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
      if (!_inputStream.hasListener) {
        channel.ref.used_buffers[bufferId] = transportBufferAvailable;
        return;
      }
      final buffer = channel.ref.buffers[bufferId];
      _inputStream.add(TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), (answer) {
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
