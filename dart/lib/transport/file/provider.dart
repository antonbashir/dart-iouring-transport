import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../configuration.dart';
import '../exception.dart';
import '../constants.dart';
import '../payload.dart';
import 'file.dart';

class TransportFile {
  final TransportFileChannel _file;
  final File delegate;

  const TransportFile(this._file, this.delegate);

  Stream<TransportPayload> get inbound => _file.inbound;
  bool get active => _file.active;

  void read({int blocksCount = 1, int offset = 0}) {
    if (blocksCount == 1) {
      _file.readSingle(offset: offset);
      return;
    }
    _file.readMany(blocksCount, offset: offset);
  }

  void writeSingle(Uint8List bytes, {TransportRetryConfiguration? retry, void Function(Exception error)? onError, void Function()? onDone}) {
    if (retry == null) {
      unawaited(_file.writeSingle(bytes, onError: onError, onDone: onDone).onError((error, stackTrace) => onError?.call(error as Exception)));
      return;
    }

    var attempt = 0;
    void _onError(Exception error) {
      if (!retry.predicate(error)) {
        onError?.call(error);
        return;
      }
      if (++attempt == retry.maxAttempts) {
        onError?.call(error);
        return;
      }
      unawaited(Future.delayed(retry.options.delay(attempt), () {
        unawaited(_file.writeSingle(bytes, onError: _onError, onDone: onDone).onError((error, stackTrace) => onError?.call(error as Exception)));
      }));
    }

    unawaited(_file.writeSingle(bytes, onError: _onError, onDone: onDone).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

  void writeMany(List<Uint8List> bytes, {TransportRetryConfiguration? retry, void Function(Exception error)? onError, void Function()? onDone}) {
    if (retry == null) {
      var doneCounter = 0;
      unawaited(_file.writeMany(bytes, onError: onError, onDone: () {
        if (++doneCounter == bytes.length) onDone?.call();
      }).onError((error, stackTrace) => onError?.call(error as Exception)));
      return;
    }

    var doneCounter = 0;
    var errorCounter = 0;
    var attempt = 0;

    void _onError(Exception error) {
      if (++errorCounter + doneCounter == bytes.length) {
        errorCounter = 0;
        if (!retry.predicate(error)) {
          onError?.call(error);
          return;
        }
        if (++attempt == retry.maxAttempts) {
          onError?.call(error);
          return;
        }
        unawaited(Future.delayed(retry.options.delay(attempt), () {
          unawaited(_file.writeMany(bytes.sublist(doneCounter), onError: _onError, onDone: () {
            if (++doneCounter == bytes.length) onDone?.call();
          }).onError((error, stackTrace) => onError?.call(error as Exception)));
        }));
      }
    }

    unawaited(_file.writeMany(bytes, onError: _onError, onDone: () {
      if (++doneCounter == bytes.length) onDone?.call();
    }).onError((error, stackTrace) => onError?.call(error as Exception)));
  }

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
              unawaited(_file.readSingle(offset: offset + bytes.length).onError((error, stackTrace) {
                if (!completer.isCompleted) completer.completeError(error!);
              }));
            },
            onError: (error) {
              if (!completer.isCompleted) {
                if (error is TransportCanceledException) {
                  completer.complete(bytes.takeBytes());
                  return;
                }
                completer.completeError(error);
              }
            },
          );
          unawaited(_file.readSingle(offset: offset).onError((error, stackTrace) {
            if (!completer.isCompleted) completer.completeError(error!);
          }));
          return completer.future.whenComplete(subscription.cancel);
        }

        var counter = 0;
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
            if (++counter == blocksCount) {
              counter = 0;
              blocksCount = min(blocksCount, max(left ~/ _file.buffers.bufferSize, 1));
              unawaited(_file.readMany(blocksCount, offset: offset + bytes.length).onError((error, stackTrace) {
                if (!completer.isCompleted) completer.completeError(error!);
              }));
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              if (error is TransportCanceledException) {
                completer.complete(bytes.takeBytes());
                return;
              }
              completer.completeError(error);
            }
          },
        );
        unawaited(_file.readMany(blocksCount, offset: offset).onError((error, stackTrace) {
          if (!completer.isCompleted) completer.completeError(error!);
        }));
        return completer.future.whenComplete(subscription.cancel);
      });

  @pragma(preferInlinePragma)
  Future<void> close({Duration? gracefulDuration}) => _file.close(gracefulDuration: gracefulDuration);
}
