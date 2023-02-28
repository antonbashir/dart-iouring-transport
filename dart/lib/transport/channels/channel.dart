import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/configuration.dart';

import '../bindings.dart';
import '../payload.dart';

class TransportChannel {
  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final Pointer<transport_controller_t> _controller;
  final TransportChannelConfiguration _configuration;

  void Function(TransportDataPayload payload)? onRead;
  void Function(TransportDataPayload payload)? onWrite;
  void Function()? onStop;

  late final Pointer<transport_channel_t> _channel;
  late final RawReceivePort _readPort = RawReceivePort(_handleRead);
  late final RawReceivePort _writePort = RawReceivePort(_handleWrite);

  TransportChannel(
    this._bindings,
    this._configuration,
    this._transport,
    this._controller, {
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
      _channel = _bindings.transport_initialize_channel(
        _transport,
        _controller,
        configuration,
        _readPort.sendPort.nativePort,
        _writePort.sendPort.nativePort,
      );
    });
  }

  void stop() {
    _readPort.close();
    _writePort.close();
    _bindings.transport_close_channel(_channel);
    onStop?.call();
  }

  void write(Uint8List bytes, int fd) {
    Pointer<Uint8> data = calloc.allocate(bytes.length).cast();
    data.asTypedList(bytes.length).setAll(0, bytes);
    _bindings.transport_channel_send(_channel, data.cast(), bytes.length, fd);
  }

  void _handleRead(dynamic payloadPointer) {
    Pointer<transport_payload> payload = Pointer.fromAddress(payloadPointer);
    if (onRead == null) {
      _bindings.transport_channel_free_payload(_channel, payload);
      return;
    }
    onRead!(TransportDataPayload(payload.ref.data.cast<Uint8>().asTypedList(payload.ref.size), this, payload.ref.fd, (finalizable) => _bindings.transport_channel_free_payload(_channel, payload)));
  }

  void _handleWrite(dynamic payloadPointer) {
    Pointer<transport_payload> payload = Pointer.fromAddress(payloadPointer);
    if (onWrite == null) {
      _bindings.transport_channel_free_buffer(_channel, payload.ref.data);
      _bindings.transport_channel_free_payload(_channel, payload);
      return;
    }
    onWrite!(TransportDataPayload(payload.ref.data.cast<Uint8>().asTypedList(payload.ref.size), this, payload.ref.fd, (finalizable) {
      _bindings.transport_channel_free_buffer(_channel, payload.ref.data);
      _bindings.transport_channel_free_payload(_channel, payload);
    }));
  }
}
