import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/loop.dart';
import 'package:iouring_transport/transport/payload.dart';

import 'bindings.dart';

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
    _bindings.transport_event_loop_read(_loop, fd, bufferId, 0, TransportEvent((event) {
      final bufferId = _bindings.transport_channel_handle_read(_loop.ref.channel, fd, event.result);
      final buffer = _loop.ref.channel.ref.buffers[bufferId];
      final payload = TransportPayload(
        buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len),
        () => _bindings.transport_channel_complete_read_by_buffer_id(_loop.ref.channel, bufferId),
      );
      completer.complete(payload);
    }));
    return completer.future;
  }

  Future<void> write(Uint8List bytes) async {
    final completer = Completer<void>.sync();
    var bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    }
    _bindings.transport_event_loop_write(_loop, fd, bufferId, 0, TransportEvent((event) {
      _bindings.transport_channel_complete_write_by_buffer_id(_loop.ref.channel, fd, bufferId);
      completer.complete();
    }));
    return completer.future;
  }
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
        TransportEvent((event) => completer.complete(TransportClientChannel(_loop, _bindings, event.result))),
      ),
    );
    return completer.future;
  }
}
