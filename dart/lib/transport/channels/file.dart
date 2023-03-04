import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:iouring_transport/transport/channels/channel.dart';

import '../bindings.dart';
import '../configuration.dart';
import '../payload.dart';

class TransportFileChannel {
  final _decoder = Utf8Decoder();
  final _encoder = Utf8Encoder();

  final TransportBindings _bindings;
  final Pointer<transport_t> _transport;
  final TransportChannelConfiguration _configuration;

  void Function(TransportDataPayload payload)? onRead;
  void Function(TransportDataPayload payload)? onWrite;
  final void Function()? onStop;

  late TransportChannel _delegate;

  TransportFileChannel(
    this._bindings,
    this._transport,
    this._configuration, {
    this.onRead,
    this.onWrite,
    this.onStop,
  }) {}

  void start() => {};

  void stop() => _delegate.stop();

  Future<Uint8List> readBytes() async {
    final currentOnRead = onRead;
    Completer completer = Completer();
    final bytes = BytesBuilder();
    var offset = 0;
    onRead = ((data) {
      if (data.bytes.isEmpty || data.bytes.last == 0) {
        completer.complete();
        return;
      }
      bytes.add(data.bytes);
      queueRead(offset: offset += data.bytes.length);
    });
    queueRead();
    await completer.future;
    final result = bytes.takeBytes();
    onRead = currentOnRead;
    return result;
  }

  Future<String> readString() => readBytes().then(_decoder.convert);

  Future<void> writeBytes(Uint8List bytes) async {
    final currentOnWrite = onWrite;
    Completer completer = Completer();
    var offset = 0;
    onWrite = (data) {
      offset += data.bytes.length;
      if (data.bytes.isEmpty || offset >= bytes.length) {
        completer.complete();
        return;
      }
      queueWrite(bytes, offset: offset);
    };
    queueWrite(bytes);
    await completer.future;
    onWrite = currentOnWrite;
  }

  Future<void> writeString(String string) => writeBytes(_encoder.convert(string));

  void queueRead({int offset = 0}) => throw Error();

  void queueWrite(Uint8List bytes, {int offset = 0}) => throw Error();
}
