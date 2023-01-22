import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:iouring_transport/transport/channels/channel.dart';

class TransportFileChannel {
  final TransportChannel _delegate;
  final _decoder = Utf8Decoder();
  final _encoder = Utf8Encoder();

  TransportFileChannel(this._delegate);

  void start() => _delegate.start();

  void stop() => _delegate.stop();

  bool get active => _delegate.active;

  Stream<Uint8List> get bytesOutput => _delegate.bytesOutput;

  Stream<String> get stringOutput => _delegate.stringOutput;

  Stream<Uint8List> get bytesInput => _delegate.bytesInput;

  Stream<String> get stringInput => _delegate.stringInput;

  Future<Uint8List> readBytes() async {
    Completer completer = Completer();
    final bytes = BytesBuilder();
    var offset = 0;
    queueRead();
    bytesOutput.listen((data) {
      if (data.isEmpty || data.first == 0) {
        completer.complete();
        return;
      }
      bytes.add(data);
      queueRead(offset: offset += data.length);
    });
    await completer.future;
    return bytes.takeBytes();
  }

  Future<String> readString() => readBytes().then(_decoder.convert);

  Future<void> writeBytes(Uint8List bytes) async {
    Completer completer = Completer();
    var offset = 0;
    queueWriteBytes(bytes);
    _delegate.bytesOutput.listen((data) {
      if (data.isEmpty || data.first == 0) {
        completer.complete();
        return;
      }
      offset += data.length;
      queueWriteBytes(bytes, position: offset, offset: offset);
    });
    await completer.future;
  }

  Future<void> writeString(String string) => writeBytes(_encoder.convert(string));

  void queueRead({int size = 64, int position = 0, int offset = 0}) => _delegate.queueRead(size: size, position: position, offset: offset);

  void queueWriteBytes(Uint8List bytes, {int position = 0, int offset = 0}) => _delegate.queueWriteBytes(bytes, position: position, offset: offset);

  void queueWriteString(String string, {int position = 0, int offset = 0}) => _delegate.queueWriteString(string, position: position, offset: offset);
}
