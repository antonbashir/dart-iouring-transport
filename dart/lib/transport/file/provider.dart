import 'dart:io';
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
  Future<void> close({Duration? gracefulDuration}) => _file.close(gracefulDuration: gracefulDuration);

  @pragma(preferInlinePragma)
  Future<Uint8List> load({int blocksCount = 1, int offset = 0}) {
    if (blocksCount == 1) return _file.readSingle().then((value) => value.takeBytes());
    final bytes = BytesBuilder();
    return _file.readMany(blocksCount, offset: offset).then((value) {
      if (value.isEmpty) return value;
      bytes.add(value);
      return load(blocksCount: blocksCount, offset: offset + value.length);
    });
  }
}
