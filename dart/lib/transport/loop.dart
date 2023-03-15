import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:iouring_transport/transport/client.dart';
import 'package:iouring_transport/transport/file.dart';
import 'package:iouring_transport/transport/logger.dart';
import 'package:iouring_transport/transport/provider.dart';

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
  bool _active = false;

  final _callbacks = TransportEventLoopCallbacks();

  final fromTransport = ReceivePort();

  late final TransportBindings _bindings;
  late final Pointer<transport_t> _transport;
  late final TransportLogger _logger;
  late final Pointer<transport_channel> _serverChannelPointer;
  late final Pointer<transport_channel> _resourceChannelPointer;
  late final TransportServerChannel _serverChannel;
  late final TransportResourceChannel _resourceChannel;
  late final int _ringSize;

  TransportEventLoop(SendPort toTransport) {
    toTransport.send(fromTransport.sendPort);
  }

  Future<void> run({
    FutureOr<void> Function(TransportProvider provider)? onRun,
    FutureOr<void> Function(TransportServerChannel channel, int descriptor)? onAccept,
    FutureOr<Uint8List> Function(Uint8List input)? onInput,
  }) async {
    if (_active) return;

    final configuration = await fromTransport.take(5).toList();
    _logger = TransportLogger(configuration[0] as TransportLogLevel);
    final libraryPath = configuration[1] as String?;
    _transport = Pointer.fromAddress(configuration[2] as int);
    _ringSize = configuration[3] as int;
    final activationPort = configuration[4] as SendPort;
    fromTransport.close();

    _bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);

    _serverChannelPointer = _bindings.transport_add_channel(_transport);
    _serverChannel = TransportServerChannel(_serverChannelPointer, _bindings);
    final serverRing = _serverChannelPointer.ref.ring;
    Pointer<Pointer<io_uring_cqe>> serverCqes = _bindings.transport_allocate_cqes(_ringSize);

    _resourceChannelPointer = _bindings.transport_channel_initialize(_transport.ref.channel_configuration);
    _resourceChannel = TransportResourceChannel(_resourceChannelPointer, _bindings);
    final resourceRing = _resourceChannelPointer.ref.ring;
    Pointer<Pointer<io_uring_cqe>> resourceCqes = _bindings.transport_allocate_cqes(_ringSize);
    final connector = TransportConnector(_callbacks, _resourceChannelPointer, _transport, _bindings);

    _active = true;

    final resourceNotifier = RawReceivePort((_) => _drainResources(resourceCqes, resourceRing));
    Isolate.spawn((List<dynamic> configuration) {
      final libraryPath = configuration[0] as String?;
      final ringSize = configuration[1] as int;
      final cqes = Pointer.fromAddress(configuration[2]);
      final ring = Pointer.fromAddress(configuration[3]);
      final notifier = configuration[4] as SendPort;
      final serverChannel = Pointer.fromAddress(configuration[5]);
      final bindings = TransportBindings(TransportLibrary.load(libraryPath: libraryPath).library);
      Timer.periodic(Duration.zero, (timer) {
        if (bindings.transport_wait(ringSize, cqes.cast(), ring.cast()) != -1) {
          notifier.send(null);
          bindings.transport_channel_awake(serverChannel.cast());
        }
      });
    }, [
      libraryPath,
      _ringSize,
      resourceCqes.address,
      resourceRing.address,
      resourceNotifier.sendPort,
      _serverChannelPointer.address,
    ]);

    await Future.value(onRun?.call(TransportProvider(connector, (path) => TransportFile(_callbacks, _resourceChannel, _bindings, path))));
    activationPort.send(null);

    Timer.periodic(Duration.zero, (timer) async {
      int cqeCount = _bindings.transport_wait(_ringSize, serverCqes, serverRing);
      if (cqeCount == -1) {
        return;
      }
      for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
        final cqe = serverCqes[cqeIndex];
        final result = cqe.ref.res;
        final userData = cqe.ref.user_data;

        if (userData & transportEventAwake != 0) {
          _drainResources(resourceCqes, resourceRing);
        }

        if (result < 0) {
          if (userData & transportEventRead != 0 || userData & transportEventWrite != 0) {
            final bufferId = userData & ~transportEventAll;
            final fd = _serverChannelPointer.ref.used_buffers[bufferId];
            _bindings.transport_close_descritor(fd);
            _serverChannelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
          }
          continue;
        }

        if (userData & transportEventRead != 0) {
          final bufferId = userData & ~transportEventAll;
          final fd = _serverChannelPointer.ref.used_buffers[bufferId];
          if (onInput == null) {
            _serverChannelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            continue;
          }
          final buffer = _serverChannelPointer.ref.buffers[bufferId];
          Future.value(onInput(buffer.iov_base.cast<Uint8>().asTypedList(result))).then((answer) {
            buffer.iov_base.cast<Uint8>().asTypedList(answer.length).setAll(0, answer);
            buffer.iov_len = answer.length;
            _bindings.transport_channel_write(_serverChannelPointer, fd, bufferId, 0, transportEventWrite);
          });
          continue;
        }

        if (userData & transportEventWrite != 0) {
          final bufferId = userData & ~transportEventAll;
          final fd = _serverChannelPointer.ref.used_buffers[bufferId];
          _bindings.transport_channel_read(_serverChannelPointer, fd, bufferId, 0, transportEventRead);
          continue;
        }

        if (userData & transportEventAccept != 0) {
          onAccept?.call(_serverChannel, result);
          continue;
        }

        if (userData & transportEventClose != 0) {
          _bindings.transport_channel_close(_serverChannelPointer);
          Isolate.exit();
        }
      }
      _bindings.transport_cqe_advance(serverRing, cqeCount);
    });
  }

  void _drainResources(Pointer<Pointer<io_uring_cqe>> cqes, Pointer<io_uring> ring) {
    int cqeCount = _bindings.transport_peek(_ringSize, cqes, ring);
    if (cqeCount == -1) {
      return;
    }
    for (var cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++) {
      final cqe = cqes[cqeIndex];
      final result = cqe.ref.res;
      final userData = cqe.ref.user_data;

      if (result < 0) {
        if (userData & transportEventConnect != 0) {
          _bindings.transport_close_descritor(userData & ~transportEventAll);
          _callbacks.notifyConnectError(userData & ~transportEventAll, Exception("Connect exception with code $result"));
        }

        if (userData & transportEventReadCallback != 0 || userData & transportEventWriteCallback != 0) {
          final bufferId = userData & ~transportEventAll;
          final fd = _resourceChannelPointer.ref.used_buffers[bufferId];
          if (userData & transportEventReadCallback != 0) {
            if (result == -EAGAIN) {
              _bindings.transport_channel_read(_resourceChannelPointer, fd, bufferId, 0, transportEventReadCallback);
              continue;
            }
            _bindings.transport_close_descritor(fd);
            _resourceChannelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            _callbacks.notifyReadError(bufferId, Exception("Read exception with code $result"));
          }
          if (userData & transportEventWriteCallback != 0) {
            if (result == -EAGAIN) {
              _bindings.transport_channel_write(_resourceChannelPointer, fd, bufferId, 0, transportEventWriteCallback);
              continue;
            }
            _bindings.transport_close_descritor(fd);
            _resourceChannelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
            _callbacks.notifyWriteError(bufferId, Exception("Write exception with code $result"));
          }
        }
        continue;
      }

      if (userData & transportEventReadCallback != 0) {
        final bufferId = userData & ~transportEventAll;
        final buffer = _resourceChannelPointer.ref.buffers[bufferId];
        _callbacks.notifyRead(bufferId, TransportPayload(buffer.iov_base.cast<Uint8>().asTypedList(result), () => _resourceChannelPointer.ref.used_buffers[bufferId] = transportBufferAvailable));
        continue;
      }

      if (userData & transportEventWriteCallback != 0) {
        final bufferId = userData & ~transportEventAll;
        _resourceChannelPointer.ref.used_buffers[bufferId] = transportBufferAvailable;
        _callbacks.notifyWrite(bufferId);
        continue;
      }

      if (userData & transportEventConnect != 0) {
        final fd = userData & ~transportEventAll;
        _callbacks.notifyConnect(fd, TransportClient(_callbacks, _resourceChannel, _bindings, fd));
        continue;
      }

      if (userData & transportEventClose != 0) {
        _bindings.transport_channel_close(_resourceChannelPointer);
        Isolate.exit();
      }
    }
    _bindings.transport_cqe_advance(ring, cqeCount);
  }
}
