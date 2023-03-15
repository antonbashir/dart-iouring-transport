import 'dart:async';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:iouring_transport/transport/loop.dart';
import 'package:tuple/tuple.dart';

import 'bindings.dart';
import 'channels.dart';
import 'payload.dart';

class TransportFile {
  final TransportBindings _bindings;
  final TransportResourceChannel _channel;
  final TransportEventLoopCallbacks _callbacks;
  late final int fd;

  TransportFile(this._callbacks, this._channel, this._bindings, String path) {
    using((Arena arena) => fd = _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
  }

  Future<TransportPayload> readBuffer({int offset = 0}) => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<TransportPayload>();
          _callbacks.putRead(Tuple2(_channel.pointer.address, bufferId), completer);
          _channel.read(fd, bufferId);
          return completer.future;
        },
      );

  Future<void> write(Uint8List bytes) => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<void>();
          _callbacks.putWrite(Tuple2(_channel.pointer.address, bufferId), completer);
          _channel.write(bytes, fd, bufferId);
          return completer.future;
        },
      );

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

  void close() => _bindings.transport_close_descritor(fd);
}
