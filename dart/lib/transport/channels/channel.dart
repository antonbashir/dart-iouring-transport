import 'dart:async';
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
  late final RawReceivePort _acceptPort = RawReceivePort();
  late final RawReceivePort _connectPort = RawReceivePort();

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
      configuration.ref.buffer_size = _configuration.bufferSize;
      configuration.ref.buffers_count = _configuration.buffersCount;
      configuration.ref.ring_size = _configuration.ringSize;
      _channel = _bindings.transport_initialize_channel(
        _transport,
        _controller,
        configuration,
        _readPort.sendPort.nativePort,
        _writePort.sendPort.nativePort,
        _acceptPort.sendPort.nativePort,
        _connectPort.sendPort.nativePort,
      );
    });
  }

  void stop() {
    _readPort.close();
    _writePort.close();
    _acceptPort.close();
    _connectPort.close();
    _bindings.transport_close_channel(_channel);
    onStop?.call();
  }

  void write(Uint8List bytes, int fd) {
    Pointer<Void> data = calloc(bytes.length);
    _bindings.transport_channel_send(_channel, data, bytes.length, fd);
  }

  void _handleRead(dynamic payloadPointer) {
    Pointer<transport_payload> payload = Pointer.fromAddress(payloadPointer);
    if (onRead == null) {
      malloc.free(payload.ref.data);
      malloc.free(payload);
      return;
    }
    onRead!(TransportDataPayload(payload, payload.ref.data.cast<Uint8>().asTypedList(payload.ref.size)));
  }

  void _handleWrite(dynamic payloadPointer) {
    Pointer<transport_payload> payload = Pointer.fromAddress(payloadPointer);
    if (onWrite == null) {
      malloc.free(payload.ref.data);
      malloc.free(payload);
      return;
    }
    onWrite!(TransportDataPayload(payload, payload.ref.data.cast<Uint8>().asTypedList(payload.ref.size)));
  }
}
