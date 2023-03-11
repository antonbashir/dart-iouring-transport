import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'payload.dart';

class TransportClientChannel {
  final Pointer<transport_event_loop_t> _loop;
  final TransportBindings _bindings;
  final int fd;

  TransportClientChannel(this._loop, this._bindings, this.fd);

  Future<TransportPayload> read() async {
    final completer = Completer<TransportPayload>.sync();
    var bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    }
    _bindings.transport_event_loop_read(_loop, fd, bufferId, 0, (result) {
      final bufferId = _bindings.transport_channel_handle_read(_loop.ref.channel, fd, result);
      final buffer = _loop.ref.channel.ref.buffers[bufferId];
      final payload = TransportPayload(
        buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len),
        () => _bindings.transport_channel_complete_read_by_buffer_id(_loop.ref.channel, bufferId),
      );
      completer.complete(payload);
    });
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final completer = Completer<void>.sync();
    var bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    }
    final buffer = _loop.ref.channel.ref.buffers[bufferId];
    buffer.iov_base.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    buffer.iov_len = bytes.length;
    _bindings.transport_event_loop_write(_loop, fd, bufferId, 0, (result) {
      _bindings.transport_channel_complete_read_by_buffer_id(_loop.ref.channel, bufferId);
      completer.complete();
    });
    return completer.future;
  }

  void close() => _bindings.transport_close_descritor(fd);
}

class TransportClient {
  final TransportBindings _bindings;
  final Pointer<transport_event_loop_t> _loop;

  TransportClient(this._loop, this._bindings);

  Future<TransportClientChannel> connect(String host, int port) async {
    final completer = Completer<TransportClientChannel>.sync();
    using(
      (arena) => _bindings.transport_event_loop_connect(
        _loop,
        host.toNativeUtf8().cast(),
        port,
        (result) => completer.complete(TransportClientChannel(_loop, _bindings, result)),
      ),
    );
    return completer.future;
  }
}
