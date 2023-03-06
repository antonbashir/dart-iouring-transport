import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../bindings.dart';
import '../configuration.dart';
import '../payload.dart';

class TransportChannel {
  final TransportBindings _bindings;

  void Function(TransportDataPayload payload)? _onRead;
  void Function(TransportDataPayload payload)? _onWrite;
  void Function()? _onStop;

  late final Pointer<transport_channel_t> channel;
  late final TransportChannelConfiguration configuration;

  final payloadPool = <int, TransportDataPayload>{};

  TransportChannel(this._bindings);

  factory TransportChannel.fromPointer(
    Pointer<transport_channel_t> pointer,
    TransportBindings _bindings, {
    void Function(TransportDataPayload payload)? onRead,
    void Function(TransportDataPayload payload)? onWrite,
    void Function()? onStop,
  }) {
    TransportChannel channel = TransportChannel(_bindings);
    channel._onRead = onRead;
    channel._onWrite = onWrite;
    channel._onStop = onStop;
    channel.channel = pointer;
    for (var bufferId = 0; bufferId < pointer.ref.buffers_count; bufferId++) {
      channel.payloadPool[bufferId] = TransportDataPayload(channel);
    }
    return channel;
  }

  void initialize(TransportChannelConfiguration configuration) {
    this.configuration = configuration;
    using((Arena arena) {
      final channelonfiguration = arena<transport_channel_configuration_t>();
      channelonfiguration.ref.buffers_count = configuration.buffersCount;
      channelonfiguration.ref.buffer_size = configuration.bufferSize;
      channel = _bindings.transport_initialize_channel(channelonfiguration);
    });
  }

  void stop() {
    _bindings.transport_close_channel(channel);
    _onStop?.call();
  }

  Future<void> write(Uint8List bytes, int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(channel);
    }
    Pointer<iovec> data = _bindings.transport_channel_get_buffer(channel, bufferId);
    data.ref.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    data.ref.iov_len = bytes.length;
    _bindings.transport_channel_write(channel, fd, bufferId);
  }

  Future<void> read(int fd) async {
    var bufferId = _bindings.transport_channel_allocate_buffer(channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(channel);
    }
    _bindings.transport_channel_read(channel, fd, bufferId);
  }

  void _readBuffer(int fd, int bufferId) => _bindings.transport_channel_read(channel, fd, bufferId);

  Future<void> handleRead(int fd, int bufferId) async {
    if (_onRead == null) {
      _bindings.transport_channel_free_buffer(channel, bufferId);
      return;
    }
    final buffer = _bindings.transport_channel_get_buffer(channel, bufferId);
    final payload = payloadPool[bufferId]!;
    payload.fd = fd;
    payload.bytes = buffer.ref.iov_base.cast<Uint8>().asTypedList(buffer.ref.iov_len);
    payload.finalizer = (payload) => _bindings.transport_channel_free_buffer(channel, bufferId);
    _onRead!(payload);
  }

  Future<void> handleWrite(int fd, int bufferId) async {
    if (_onWrite == null) {
      _bindings.transport_channel_free_buffer(channel, bufferId);
      _readBuffer(fd, bufferId);
      return;
    }
    final buffer = _bindings.transport_channel_get_buffer(channel, bufferId);
    final payload = payloadPool[bufferId]!;
    payload.fd = fd;
    payload.bytes = buffer.ref.iov_base.cast<Uint8>().asTypedList(buffer.ref.iov_len);
    payload.finalizer = (payload) async {
      _bindings.transport_channel_free_buffer(channel, bufferId);
      _readBuffer(fd, bufferId);
    };
    _onWrite!(payload);
  }
}
