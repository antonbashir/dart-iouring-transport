import 'dart:async';
import 'dart:ffi';
import 'dart:io';
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
  final Pointer<transport_channel_t> _channelPointer;
  final TransportEventLoopCallbacks _callbacks;
  late int _fd;

  TransportFile(this._callbacks, this._channel, this._channelPointer, this._bindings, String path) {
    using((Arena arena) => _fd = _bindings.transport_file_open(path.toNativeUtf8(allocator: arena).cast()));
  }

  Future<TransportPayload> readBuffer({int offset = 0}) => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<TransportPayload>();
          _callbacks.putRead(Tuple2(_channelPointer.address, bufferId), completer);
          _channel.read(_fd, bufferId, offset: offset);
          return completer.future;
        },
      );

  Future<void> write(Uint8List bytes, {int offset = 0}) => _channel.allocate().then(
        (bufferId) {
          final completer = Completer<void>();
          _callbacks.putWrite(Tuple2(_channelPointer.address, bufferId), completer);
          _channel.write(bytes, _fd, bufferId, offset: offset);
          return completer.future;
        },
      );

  void send(Uint8List bytes, {int offset = 0}) => _channel.allocate().then((bufferId) => _channel.write(bytes, _fd, bufferId, offset: offset));

  Future<TransportPayload> read() async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    var payload = await readBuffer(offset: offset);
    final payloads = <TransportPayload>[];
    payloads.add(payload);
    builder.add(payload.bytes);
    offset += payload.bytes.length;
    payload.release();
    while (true) {
      payload = await readBuffer(offset: offset);
      if (payload.bytes.isEmpty) {
        break;
      }
      payloads.add(payload);
      builder.add(payload.bytes);
      offset += payload.bytes.length;
      payload.release();
    }
    return TransportPayload(builder.takeBytes(), (answer, offset) => payloads.forEach((payload) => payload.release()));
  }

  void close() => _bindings.transport_close_descritor(_fd);
}
