import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:iouring_transport/transport/sequences.dart';
import 'package:iouring_transport/transport/worker.dart';

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
    _states.setOutboundRead(bufferId, completer);
    _channel.addRead(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, 0, offset: offset);
    _worker.submitOutbound();
    return completer.future.then((length) => _pool.getPayload(bufferId, _buffers.read(bufferId)));
  }

  Future<Uint8List> readSequence(int count, {int offset = 0}) async {
    final bytes = BytesBuilder();
    final sequenceId = _sequences.get() ?? await _sequences.allocate();
    for (var i = 0; i < count - 1; i++) {
      final bufferId = _buffers.get() ?? await _buffers.allocate();
      _channel.addRead(
        bufferId,
        transportTimeoutInfinity,
        transportEventRead | transportEventFile,
        transportIosqeIoLink,
        sequenceId: sequenceId,
        offset: offset,
      );
    }
    final completer = Completer<int>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundRead(bufferId, completer);
    _channel.addRead(
      bufferId,
      transportTimeoutInfinity,
      transportEventRead | transportEventFile,
      0,
      sequenceId: sequenceId,
      offset: offset,
    );
    _worker.submitOutbound();
    await completer.future;
    _sequences.drain(sequenceId, count, (element) {
      bytes.add(_buffers.read(element.ref.buffer_id));
      _buffers.release(bufferId);
    });
    return bytes.takeBytes();
  }

  @pragma(preferInlinePragma)
  Future<TransportPayload> _addRead(int bufferId, {int offset = 0}) {
    final completer = Completer<int>();
    _states.setOutboundRead(bufferId, completer);
    _channel.addRead(bufferId, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    return completer.future.then((length) => _pool.getPayload(bufferId, _buffers.read(bufferId, length)));
  }

  Stream<List<int>> stream({int batchCount = 32}) async* {
    var offset = 0;
    while (true) {
      final allocatedBuffers = <int>[];
      for (var i = 0; i < batchCount; i++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());
      final bytes = BytesBuilder();
      for (var i = 0; i < batchCount - 1; i++) {
        _addRead(allocatedBuffers[i], offset: offset).then((fragmentPayload) {
          if (fragmentPayload.bytes.isEmpty) {
            fragmentPayload.release();
            return;
          }
          bytes.add(fragmentPayload.bytes);
          fragmentPayload.release();
        });
        offset += _buffers.bufferSize;
      }
      final submitCompleter = Completer<int>();
      _states.setOutboundRead(allocatedBuffers[batchCount - 1], submitCompleter);
      _channel.readSubmit(allocatedBuffers[batchCount - 1], transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
      final payload = await submitCompleter.future.then((length) => _pool.getPayload(allocatedBuffers[batchCount - 1], _buffers.read(allocatedBuffers[batchCount - 1], length)));
      offset += _buffers.bufferSize;
      if (payload.bytes.isEmpty) {
        payload.release();
        break;
      }
      bytes.add(payload.bytes);
      yield bytes.takeBytes();
      payload.release();
    }
  }

  Future<Uint8List> load({int batchCount = 8}) async {
    BytesBuilder builder = BytesBuilder();
    var offset = 0;
    final delta = _buffers.bufferSize * batchCount;
    final completer = Completer<Uint8List>();
    final allocatedBuffers = <int>[];
    for (var i = 0; i < batchCount; i++) allocatedBuffers.add(_buffers.get() ?? await _buffers.allocate());

    void _read(TransportPayload payload) async {
      offset += delta;
      if (payload.bytes.isEmpty) {
        payload.release();
        completer.complete(builder.takeBytes());
        return;
      }
      builder.add(payload.bytes);
      payload.release();
      for (var i = 0; i < batchCount - 1; i++) {
        _addRead(allocatedBuffers[i], offset: offset).then((fragmentPayload) {
          builder.add(fragmentPayload.bytes);
          fragmentPayload.release();
        });
      }
      final submitCompleter = Completer<int>();
      final buffer = allocatedBuffers[batchCount - 1];
      _states.setOutboundRead(buffer, submitCompleter);
      _channel.readSubmit(buffer, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
      submitCompleter.future.then((length) => _read(_pool.getPayload(buffer, _buffers.read(buffer, length))));
    }

    for (var i = 0; i < batchCount - 1; i++) {
      _addRead(allocatedBuffers[i], offset: offset).then((fragmentPayload) {
        builder.add(fragmentPayload.bytes);
        fragmentPayload.release();
      });
    }
    final submitCompleter = Completer<int>();
    final buffer = allocatedBuffers[batchCount - 1];
    _states.setOutboundRead(buffer, submitCompleter);
    _channel.readSubmit(buffer, transportTimeoutInfinity, transportEventRead | transportEventFile, offset: offset);
    submitCompleter.future.then((length) => _read(_pool.getPayload(buffer, _buffers.read(buffer, length))));
    return completer.future;
  }

  Future<void> write(Uint8List bytes, {int offset = 0}) async {
    final completer = Completer<void>();
    final bufferId = _buffers.get() ?? await _buffers.allocate();
    _states.setOutboundWrite(bufferId, completer);
    _channel.writeSubmit(bytes, bufferId, transportTimeoutInfinity, transportEventWrite | transportEventFile, offset: offset);
    return completer.future;
  }

  void close() => _channel.close();
}
