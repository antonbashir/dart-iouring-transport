import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';
import 'loop.dart';
import 'payload.dart';

class TransportFileChannel {
  final Pointer<transport_event_loop_t> _loop;
  final TransportBindings _bindings;
  final int fd;

  TransportFileChannel(this._loop, this._bindings, this.fd);

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>.sync();
    var bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    }
    _bindings.transport_event_loop_write(_loop, fd, bufferId, offset, TransportEvent((event) {
      _bindings.transport_channel_complete_write_by_buffer_id(_loop.ref.channel, fd, bufferId);
      completer.complete();
    }));
    return completer.future;
  }

  Future<Uint8List> read() async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    var payload = await readBuffer(offset: offset);
    while (payload.bytes.isNotEmpty) {
      builder.add(payload.bytes);
      offset += payload.bytes.length;
      payload = await readBuffer(offset: offset);
    }
    return builder.takeBytes();
  }

  Future<TransportPayload> readBuffer({int offset = 0}) async {
    final completer = Completer<TransportPayload>.sync();
    var bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    while (bufferId == -1) {
      await Future.delayed(Duration.zero);
      bufferId = _bindings.transport_channel_allocate_buffer(_loop.ref.channel);
    }
    _bindings.transport_event_loop_read(_loop, fd, bufferId, offset, TransportEvent((event) {
      final bufferId = _bindings.transport_channel_handle_read(_loop.ref.channel, fd, event.result);
      final buffer = _loop.ref.channel.ref.buffers[bufferId];
      final payload = TransportPayload(
        buffer.iov_base.cast<Uint8>().asTypedList(buffer.iov_len),
        () => _bindings.transport_channel_complete_read_by_buffer_id(_loop.ref.channel, bufferId),
      );
      _bindings.transport_channel_complete_read_by_buffer_id(_loop.ref.channel, bufferId);
      completer.complete(payload);
    }));
    return completer.future;
  }

  void close() => _bindings.transport_close_descritor(fd);
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
