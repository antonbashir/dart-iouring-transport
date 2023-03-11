import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/loop.dart';

import 'bindings.dart';

class TransportFileChannel {
  final Pointer<transport_event_loop_t> _loop;
  final TransportBindings _bindings;
  final int fd;

  TransportFileChannel(this._loop, this._bindings, this.fd);

  Future<T> read<T>(T Function(Uint8List bytes) parser) async {
    final completer = Completer<T>.sync();
    var bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    }
    _bindings.transport_event_loop_read(_loop, fd, bufferId, TransportEvent((event) {
      final bufferId = _bindings.transport_channel_handle_read(_loop.ref.channel, fd, event.result);
      final buffer = _loop.ref.channel.ref.buffers[bufferId];
      final parsed = parser(buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len));
      _bindings.transport_channel_complete_read_by_buffer_id(_loop.ref.channel, bufferId);
      completer.complete(parsed);
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
    _bindings.transport_event_loop_read(_loop, fd, bufferId, TransportEvent((event) {
      final bufferId = _bindings.transport_channel_handle_read(_loop.ref.channel, fd, event.result);
      _bindings.transport_channel_complete_write_by_buffer_id(_loop.ref.channel, fd, bufferId);
      completer.complete();
    }));
    return completer.future;
  }
}

class TransportFile {
  final TransportBindings _bindings;
  final Pointer<transport_event_loop_t> _loop;

  TransportFile(this._loop, this._bindings);

  TransportFileChannel open(String path) => using(
        (arena) => TransportFileChannel(
          _loop,
          _bindings,
          _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()),
        ),
      );
}
