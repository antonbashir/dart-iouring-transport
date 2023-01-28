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
  final Pointer<transport_listener_t> _listener;
  final TransportChannelConfiguration _configuration;
  final int _descriptor;

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
    this._listener,
    this._descriptor, {
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
      configuration.ref.buffer_initial_capacity = _configuration.bufferInitialCapacity;
      configuration.ref.buffer_limit = _configuration.bufferLimit;
      configuration.ref.payload_buffer_size = _configuration.payloadBufferSize;
      _channel = _bindings.transport_initialize_channel(
        _transport,
        _listener,
        configuration,
        _descriptor,
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

  Future<void> queueRead({int offset = 0}) async {
    while (_bindings.transport_channel_prepare_read(_channel) == nullptr) {
      await Future.delayed(_configuration.bufferAvailableAwaitDelayed);
    }
    _bindings.transport_channel_queue_read(_channel, offset);
    _bindings.transport_listener_poll(_listener, false);
  }

  Future<void> queueWrite(Uint8List bytes, {int offset = 0}) async {
    Pointer<Uint8> buffer = _bindings.transport_channel_prepare_write(_channel).cast();
    while (buffer == nullptr) {
      await Future.delayed(_configuration.bufferAvailableAwaitDelayed);
      buffer = _bindings.transport_channel_prepare_write(_channel).cast();
    }
    buffer.asTypedList(bytes.length).setAll(0, bytes);
    _bindings.transport_channel_queue_write(_channel, bytes.length, offset);
    _bindings.transport_listener_poll(_listener, false);
  }

  int currentReadSize() => _channel.ref.current_read_size;

  int currentWriteSize() => _channel.ref.current_write_size;

  void _handleRead(dynamic payloadPointer) {
    Pointer<transport_data_payload> payload = Pointer.fromAddress(payloadPointer);
    if (payload == nullptr) return;
    if (onRead == null) {
      _bindings.transport_channel_free_data_payload(_channel, payload);
      return;
    }
    final readBuffer = _bindings.transport_channel_extract_read_buffer(_channel, payload);
    final bytes = readBuffer.cast<Uint8>().asTypedList(payload.ref.size);
    onRead!(TransportDataPayload(_bindings, _channel, payload, bytes));
  }

  void _handleWrite(dynamic payloadPointer) {
    Pointer<transport_data_payload> payload = Pointer.fromAddress(payloadPointer);
    if (payload == nullptr) return;
    if (onWrite == null) {
      _bindings.transport_channel_free_data_payload(_channel, payload);
      return;
    }
    final writeBuffer = _bindings.transport_channel_extract_write_buffer(_channel, payload);
    final bytes = writeBuffer.cast<Uint8>().asTypedList(payload.ref.size);
    onWrite!(TransportDataPayload(_bindings, _channel, payload, bytes));
  }
}
