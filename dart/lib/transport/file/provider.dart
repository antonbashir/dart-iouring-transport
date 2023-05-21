import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../constants.dart';
import 'file.dart';

class TransportFileProvider {
  final TransportFile _file;
  final File delegate;

  const TransportFileProvider(this._file, this.delegate);

  bool get active => !_file.closing;

  @pragma(preferInlinePragma)
  Future<void> writeSingle(Uint8List bytes, {int offset = 0}) => _file.writeSingle(bytes, offset: offset);

  @pragma(preferInlinePragma)
  Future<void> writeMany(List<Uint8List> bytes, {int offset = 0}) => _file.writeMany(bytes, offset: offset);

  @pragma(preferInlinePragma)
  Future<Uint8List> load({int blocksCount = 1, int offset = 0}) => delegate.stat().then((stat) {
        final bytes = BytesBuilder();
        final completer = Completer<Uint8List>();
        if (blocksCount == 1) {
          final subscription = _file.inbound.listen(
            (payload) {
              final payloadBytes = payload.takeBytes();
              if (payloadBytes.isEmpty) {
                completer.complete(bytes.takeBytes());
                return;
              }
              bytes.add(payloadBytes);
              final left = stat.size - bytes.length;
              if (left == 0) {
                completer.complete(bytes.takeBytes());
                return;
              }
              _file.readSingle(offset: offset += bytes.length);
            },
          );
          _file.readSingle(offset: offset);
          return completer.future.whenComplete(() => subscription.cancel());
        }
        final subscription = _file.inbound.listen(
          (payload) {
            final payloadBytes = payload.takeBytes();
            if (payloadBytes.isEmpty) {
              completer.complete(bytes.takeBytes());
              return;
            }
            bytes.add(payloadBytes);
            final left = stat.size - bytes.length;
            if (left == 0) {
              completer.complete(bytes.takeBytes());
              return;
            }
            _file.readMany(blocksCount, offset: offset += bytes.length);
          },
        );
        _file.readMany(blocksCount, offset: offset);
        return completer.future.whenComplete(() => subscription.cancel());
      });

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _file.close(gracefulDuration: gracefulDuration);
}
