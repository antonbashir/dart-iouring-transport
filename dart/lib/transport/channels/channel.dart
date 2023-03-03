import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/acceptor.dart';
import 'package:iouring_transport/transport/configuration.dart';

import '../bindings.dart';
import '../payload.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final TransportChannelConfiguration _configuration;
  final TransportAcceptor _acceptor;

  void Function(TransportDataPayload payload)? onRead;
  void Function(TransportDataPayload payload)? onWrite;
  void Function()? onStop;

  late final Pointer<transport_channel_t> channel;
  late final RawReceivePort _acceptPort = RawReceivePort(_handleAccept);
  late final RawReceivePort _readPort = RawReceivePort(_handleRead);
  late final RawReceivePort _writePort = RawReceivePort(_handleWrite);

  TransportChannel(
    this._bindings,
    this._acceptor,
    this._configuration,
    this._transport, {
    this.onRead,
    this.onWrite,
    this.onStop,
  });

  void start({
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    if (onRead != null) this.onRead = onRead;
    if (onWrite != null) this.onWrite = onWrite;
    if (onStop != null) this.onStop = onStop;
    using((Arena arena) {
      final configuration = arena<transport_channel_configuration_t>();
      configuration.ref.buffers_count = _configuration.buffersCount;
      configuration.ref.buffer_shift = _configuration.bufferShift;
      configuration.ref.ring_size = _configuration.ringSize;
      channel = _bindings.transport_initialize_channel(
        _transport,
        configuration,
        _acceptPort.sendPort.nativePort,
        _readPort.sendPort.nativePort,
        _writePort.sendPort.nativePort,
      );
    });
  }

  void stop() {
    _readPort.close();
    _writePort.close();
    _bindings.transport_close_channel(channel);
    onStop?.call();
  }

  void write(Uint8List bytes, int fd) async {
    int bufferId = _bindings.transport_channel_select_write_buffer(channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_select_write_buffer(channel);
    }
    Pointer<iovec> data = _bindings.transport_channel_use_write_buffer(channel, bufferId);
    data.ref.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    data.ref.iov_len = bytes.length;
    _bindings.transport_channel_write(channel, fd, bufferId);
  }

  void _read(int fd) async {
    int bufferId = _bindings.transport_channel_select_read_buffer(channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_select_read_buffer(channel);
    }
    _bindings.transport_channel_read(channel, fd, bufferId);
  }

  void _handleAccept(int fd) {
    _read(fd);
    _acceptor.accept();
  }

  void _handleRead(int fd) {
    final bufferId = _bindings.transport_channel_get_buffer_by_fd(channel, fd);
    if (onRead == null) {
      _bindings.transport_channel_free_buffer(channel, bufferId);
      return;
    }
    final buffer = _bindings.transport_channel_use_read_buffer(channel, bufferId);
    onRead!(
      TransportDataPayload(
        buffer.ref.iov_base.cast<Uint8>().asTypedList(buffer.ref.iov_len),
        this,
        fd,
        (finalizable) => _bindings.transport_channel_free_buffer(channel, bufferId),
      ),
    );
  }

  void _handleWrite(int fd) {
    final bufferId = _bindings.transport_channel_get_buffer_by_fd(channel, fd);
    _read(fd);
    if (onWrite == null) {
      _bindings.transport_channel_free_buffer(channel, bufferId);
      return;
    }
    final buffer = _bindings.transport_channel_use_write_buffer(channel, bufferId);
    onWrite!(
      TransportDataPayload(
        buffer.ref.iov_base.cast<Uint8>().asTypedList(buffer.ref.iov_len),
        this,
        fd,
        (finalizable) => _bindings.transport_channel_free_buffer(channel, bufferId),
      ),
    );
  }
}
