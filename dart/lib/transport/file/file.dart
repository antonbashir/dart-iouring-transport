import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import '../sequences.dart';
import '../worker.dart';
import '../buffers.dart';
import '../channel.dart';
import '../constants.dart';
import '../payload.dart';
import '../callbacks.dart';

class TransportFile {
  final String path;
  final TransportChannel _channel;
  final TransportCallbacks _states;
  final TransportBuffers _buffers;
  final TransportSequences _sequences;
  final TransportPayloadPool _pool;
  final TransportWorker _worker;
  final File delegate;

  TransportFile(
    this.path,
    this.delegate,
    this._states,
    this._channel,
    this._buffers,
    this._sequences,
    this._pool,
    this._worker,
  );

  Future<TransportPayload> read({int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundBuffer(bufferId, completer);
    _channel.addRead(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, 0, offset: offset);
    _worker.submitOutbound();
    return completer.future.then((length) => _pool.getPayload(bufferId, _buffers.read(bufferId)));
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundBuffer(bufferId, completer);
    _channel.addWrite(bytes, bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, 0, offset: offset);
    _worker.submitOutbound();
    await completer.future;
  }

  @pragma(preferInlinePragma)
  Future<Uint8List> readSequence(int count, {int offset = 0}) {
    final bytes = BytesBuilder();
    return _sequence(
      count,
      (_, offset, bufferId, sqeFlags) => _channel.addRead(
        bufferId,
        transportTimeoutInfinity,
        transportEventRead | transportEventFile,
        sqeFlags,
        offset: offset,
      ),
      handle: bytes.add,
    ).then((_) => bytes.takeBytes());
  }

  @pragma(preferInlinePragma)
  Stream<Uint8List> streamSequence(int count, {int offset = 0}) async* {
    final stream = StreamController<Uint8List>(sync: true);
    yield* stream.stream;
    _sequence(
      count,
      (_, offset, bufferId, sqeFlags) => _channel.addRead(
        bufferId,
        transportTimeoutInfinity,
        transportEventRead | transportEventFile,
        sqeFlags,
        offset: offset,
      ),
      handle: stream.add,
    );
  }

  @pragma(preferInlinePragma)
  Future<void> writeSequence(List<Uint8List> bytes, {int offset = 0}) => _sequence(
        bytes.length,
        (index, offset, bufferId, sqeFlags) => _channel.addWrite(
          bytes[index],
          bufferId,
          transportTimeoutInfinity,
          transportEventWrite | transportEventFile,
          sqeFlags,
          offset: offset,
        ),
      );

  Future<void> _sequence(int count, void Function(int index, int offset, int bufferId, int sqeFlags) addEvent, {void Function(Uint8List bytes)? handle, int offset = 0}) async {
    final sequenceId = _sequences.get() ?? await _sequences.allocate();
    for (var i = 0; i < count - 1; i++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _sequences.add(sequenceId, bufferId);
      addEvent(i, offset, bufferId, transportIosqeIoLink);
      offset += _buffers.bufferSize;
    }
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundBuffer(bufferId, completer);
    _sequences.add(sequenceId, bufferId);
    addEvent(count, offset, bufferId, 0);
    _worker.submitOutbound();
    await completer.future;
    if (handle != null) {
      _sequences.drain(sequenceId, count, (element) {
        final payload = _buffers.read(element.ref.buffer_id);
        handle(payload);
        _buffers.release(bufferId);
        return payload.isNotEmpty;
      });
    }
  }

  void close() => _channel.close();
}
