import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'file.dart';

class TransportFileProvider {
  final TransportFile _file;
  final File delegate;

  TransportFileProvider(this._file, this.delegate);

  @pragma(preferInlinePragma)
  Future<TransportPayload> readSingle({bool submit = true, int offset = 0}) => _file.readSingle(submit: submit, offset: offset);

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes, {bool submit = true, int offset = 0}) => _file.writeSingle(bytes, submit: submit, offset: offset);

  @pragma(preferInlinePragma)
  Future<Uint8List> readMany(int count, {bool submit = true, int offset = 0}) => _file.readMany(count, submit: submit, offset: offset);

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes, {bool submit = true, int offset = 0}) => _file.writeMany(bytes, submit: submit, offset: offset);

  @pragma(preferInlinePragma)
  Future<Uint8List> load({int blocksCount = 1, int offset = 0}) => delegate.stat().then((stat) {
        final bytes = BytesBuilder();

        Future<Uint8List> single(int blocksCount, int offset) => _file.readSingle().then(
              (payload) {
                final payloadBites = payload.takeBytes();
                if (payloadBites.isEmpty) return bytes.takeBytes();
                bytes.add(payloadBites);
                final left = stat.size - bytes.length;
                if (left == 0) return bytes.takeBytes();
                return single(blocksCount, offset + payloadBites.length);
              },
            );

        Future<Uint8List> many(int blocksCount, int offset) => _file.readMany(blocksCount, offset: offset).then(
              (value) {
                if (value.isEmpty) return bytes.takeBytes();
                bytes.add(value);
                final left = stat.size - bytes.length;
                if (left == 0) return bytes.takeBytes();
                return many(min(blocksCount, max(left ~/ _file.buffers.bufferSize, 1)), offset + value.length);
              },
            );

        return (blocksCount == 1 ? single(blocksCount, offset) : many(blocksCount, offset));
      });

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _file.close(gracefulDuration: gracefulDuration);
}
