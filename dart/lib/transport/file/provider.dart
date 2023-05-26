import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../constants.dart';
import '../payload.dart';
import 'file.dart';

class TransportFile {
  final TransportFileChannel _file;
  final File delegate;

  const TransportFile(this._file, this.delegate);

  Stream<TransportPayload> get inbound => _file.inbound;
  bool get active => _file.active;

  @pragma(preferInlinePragma)
  void writeSingle(Uint8List bytes, {int offset = 0, void Function(Exception error)? onError}) => unawaited(_file.writeSingle(bytes, offset: offset, onError: onError));

  @pragma(preferInlinePragma)
  void writeMany(List<Uint8List> bytes, {int offset = 0, void Function(Exception error)? onError}) => unawaited(_file.writeMany(bytes, offset: offset, onError: onError));

  @pragma(preferInlinePragma)
  Future<Uint8List> read({int blocksCount = 1, int offset = 0}) => delegate.stat().then((stat) {
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
              unawaited(_file.readSingle(offset: offset + bytes.length));
            },
          );
          unawaited(_file.readSingle(offset: offset));
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
            unawaited(_file.readMany(min(blocksCount, max(left ~/ _file.buffers.bufferSize, 1)), offset: offset + bytes.length));
          },
        );
        unawaited(_file.readMany(blocksCount, offset: offset));
        return completer.future.whenComplete(() => subscription.cancel());
      });

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _file.close(gracefulDuration: gracefulDuration);
}
