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

  final _inputStream = StreamController<TransportPayload>(sync: true);

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

  void _handleOutbound(int result, int userData, Pointer<transport_channel_t> pointer) {
    if (result < 0) {
      if (userData & transportEventConnect != 0) {
        _bindings.transport_close_descritor(userData & ~transportEventAll);
        _callbacks.notifyConnectError(userData & ~transportEventAll, Exception("Connect exception with code $result"));
        return;
      }

      if (userData & transportEventReadCallback != 0) {
        final channel = TransportChannel.channel(pointer.address);
        final bufferId = userData & ~transportEventAll;
        final fd = pointer.ref.used_buffers[bufferId];
        if (result == -EAGAIN) {
          _bindings.transport_channel_read(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], transportEventReadCallback);
          return;
        }
        _bindings.transport_close_descritor(fd);
        channel.free(bufferId);
        _callbacks.notifyReadError(Tuple2(pointer.address, bufferId), Exception("Read exception with code $result"));
        return;
      }

      if (userData & transportEventWriteCallback != 0) {
        final channel = TransportChannel.channel(pointer.address);
        final bufferId = userData & ~transportEventAll;
        final fd = pointer.ref.used_buffers[bufferId];
        if (result == -EAGAIN) {
          _bindings.transport_channel_write(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], transportEventWriteCallback);
          return;
        }
        _bindings.transport_close_descritor(fd);
        channel.free(bufferId);
        _callbacks.notifyWriteError(Tuple2(pointer.address, bufferId), Exception("Write exception with code $result"));
        return;
      }
      return;
    }

    if (userData & transportEventReadCallback != 0) {
      final channel = TransportChannel.channel(pointer.address);
      final bufferId = userData & ~transportEventAll;
      final buffer = pointer.ref.buffers[bufferId];
      final fd = pointer.ref.used_buffers[bufferId];
      _callbacks.notifyRead(
        Tuple2(pointer.address, bufferId),
        TransportPayload(
          buffer.iov_base.cast<Uint8>().asTypedList(result),
          (answer, offset) {
            if (answer != null) {
              buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
              buffer.iov_len = answer.length;
              _bindings.transport_channel_write(pointer, fd, bufferId, 0, transportEventWrite);
              return;
            }
            channel.free(bufferId);
          },
        ),
      );
      return;
    }

    if (userData & transportEventWriteCallback != 0) {
      final channel = TransportChannel.channel(pointer.address);
      final bufferId = userData & ~transportEventAll;
      channel.free(bufferId);
      _callbacks.notifyWrite(Tuple2(pointer.address, bufferId));
      return;
    }

    if (userData & transportEventConnect != 0) {
      final fd = userData & ~transportEventAll;
      _callbacks.notifyConnect(
        fd,
        TransportClient(_callbacks, TransportResourceChannel(pointer, _bindings), _bindings, fd),
      );
      return;
    }
  }

  void _handleInbound(int result, int userData, Pointer<transport_channel_t> pointer) {
    if (result < 0) {
      if (userData & transportEventRead != 0) {
        final channel = TransportChannel.channel(pointer.address);
        final bufferId = userData & ~transportEventAll;
        final fd = pointer.ref.used_buffers[bufferId];
        if (result == -EAGAIN) {
          _bindings.transport_channel_read(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], transportEventRead);
          return;
        }
        _bindings.transport_close_descritor(fd);
        channel.free(bufferId);
        return;
      }

      if (userData & transportEventWrite != 0) {
        final channel = TransportChannel.channel(pointer.address);
        final bufferId = userData & ~transportEventAll;
        final fd = pointer.ref.used_buffers[bufferId];
        if (result == -EAGAIN) {
          _bindings.transport_channel_write(pointer, fd, bufferId, pointer.ref.used_buffers_offsets[bufferId], transportEventWrite);
          return;
        }
        _bindings.transport_close_descritor(fd);
        channel.free(bufferId);
        return;
      }
      return;
    }

    if (userData & transportEventRead != 0) {
      final channel = TransportChannel.channel(pointer.address);
      final bufferId = userData & ~transportEventAll;
      final fd = pointer.ref.used_buffers[bufferId];
      if (!_inputStream.hasListener) {
        channel.free(bufferId);
        return;
      }
      final buffer = pointer.ref.buffers[bufferId];
      _inputStream.add(TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), (answer, offset) {
        if (answer != null) {
          buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
          buffer.iov_len = answer.length;
          _bindings.transport_channel_write(pointer, fd, bufferId, offset, transportEventWrite);
          return;
        }
        channel.free(bufferId);
      }));
      return;
    }

    if (userData & transportEventWrite != 0) {
      final bufferId = userData & ~transportEventAll;
      final fd = pointer.ref.used_buffers[bufferId];
      _bindings.transport_channel_read(pointer, fd, bufferId, 0, transportEventRead);
      return;
    }

    if (userData & transportEventAccept != 0) {
      onAccept?.call(TransportServerChannel(pointer, _bindings), result);
      return;
    }
  }
}
