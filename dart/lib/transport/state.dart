import 'dart:async';

import 'client.dart';
import 'configuration.dart';
import 'constants.dart';
import 'payload.dart';
import 'retry.dart';

class TransportEventState {
  late Completer<dynamic> callback;
  late TransportRetryState retry;

  TransportEventState();

  factory TransportEventState.forCallback(Completer<dynamic> callback) {
    final state = TransportEventState();
    state.callback = callback;
    return state;
  }

  factory TransportEventState.forRetry(TransportRetryState retryState) {
    final state = TransportEventState();
    state.retry = retryState;
    return state;
  }

  factory TransportEventState.forRetryCallback(Completer<dynamic> callback, TransportRetryState retryState) {
    final state = TransportEventState();
    state.callback = callback;
    state.retry = retryState;
    return state;
  }
}

class TransportEventStates {
  final _connect = <int, TransportEventState>{};
  final _inboundRead = <TransportEventState>[];
  final _inboundWrite = <TransportEventState>[];
  final _outboundRead = <TransportEventState>[];
  final _outboundWrite = <TransportEventState>[];
  final _custom = <int, TransportEventState>{};

  void initliaze(int buffersCount) {
    for (var index = 0; index < buffersCount; index++) {
      _inboundRead[index] = TransportEventState();
      _inboundWrite[index] = TransportEventState();
      _outboundRead[index] = TransportEventState();
      _outboundWrite[index] = TransportEventState();
    }
  }

  @pragma(preferInlinePragma)
  void setConnectCallback(int fd, Completer<TransportClient> completer, TransportRetryState retryState) => _connect[fd] = TransportEventState.forRetryCallback(completer, retryState);

  @pragma(preferInlinePragma)
  void setOutboundReadCallback(int bufferId, Completer<TransportOutboundPayload> completer, TransportRetryState retryState) {
    final state = _outboundRead[bufferId];
    state.callback = completer;
    state.retry = retryState;
  }

  @pragma(preferInlinePragma)
  void setOutboundWriteCallback(int bufferId, Completer<void> completer, TransportRetryState retryState) {
    final state = _outboundWrite[bufferId];
    state.callback = completer;
    state.retry = retryState;
  }

  @pragma(preferInlinePragma)
  void setCustomCallback(int id, Completer<int> completer) => _custom[id] = TransportEventState.forCallback(completer);

  @pragma(preferInlinePragma)
  void notifyConnectCallback(int fd, TransportClient client) => _connect.remove(fd)!.callback.complete(client);

  @pragma(preferInlinePragma)
  void notifyOutboundReadCallback(int bufferId, TransportOutboundPayload payload) => _outboundRead[bufferId].callback.complete(payload);

  @pragma(preferInlinePragma)
  void notifyOutboundWriteCallback(int bufferId) => _outboundWrite[bufferId].callback.complete();

  @pragma(preferInlinePragma)
  void notifyCustomCallback(int id, int data) => _custom[id]!.callback.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectCallbackError(int fd, Exception error) => _connect.remove(fd)!.callback.completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundReadCallbackError(int bufferId, Exception error) => _outboundRead[bufferId].callback.completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundWriteCallbackError(int bufferId, Exception error) => _outboundWrite[bufferId].callback.completeError(error);

  Future<bool> incrementConnect(int fd, TransportRetryConfiguration retry) async {
    final current = _connect[fd]!.retry;
    if (current.count == retry.maxRetries) {
      current.reset();
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    current.update(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementInboundRead(int bufferId, TransportRetryConfiguration retry) async {
    final current = _inboundRead[bufferId].retry;
    if (current.count == retry.maxRetries) {
      current.reset();
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    current.update(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementInboundWrite(int bufferId, TransportRetryConfiguration retry) async {
    final current = _inboundWrite[bufferId].retry;
    if (current.count == retry.maxRetries) {
      current.reset();
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    current.update(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementOutboundRead(int bufferId, TransportRetryConfiguration retry) async {
    final current = _outboundRead[bufferId].retry;
    if (current.count == retry.maxRetries) {
      current.reset();
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    current.update(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  Future<bool> incrementOutboundWrite(int bufferId, TransportRetryConfiguration retry) async {
    final current = _outboundWrite[bufferId].retry;
    if (current.count == retry.maxRetries) {
      current.reset();
      return false;
    }
    final newDelay = Duration(
      microseconds: (current.delay.inMicroseconds * retry.backoffFactor).floor().clamp(retry.initialDelay.inMicroseconds, retry.maxDelay.inMicroseconds),
    );
    current.update(newDelay, current.count + 1);
    return Future.delayed(newDelay).then((value) => true);
  }

  @pragma(preferInlinePragma)
  void resetConnect(int fd) => _connect[fd]!.retry.reset();

  @pragma(preferInlinePragma)
  void resetInboundRead(int bufferId) => _inboundRead[bufferId].retry.reset();

  @pragma(preferInlinePragma)
  void resetInboundWrite(int bufferId) => _inboundWrite[bufferId].retry.reset();

  @pragma(preferInlinePragma)
  void resetOutboundRead(int bufferId) => _outboundRead[bufferId].retry.reset();

  @pragma(preferInlinePragma)
  void resetOutboundWrite(int bufferId) => _outboundWrite[bufferId].retry.reset();

  @pragma(preferInlinePragma)
  TransportEventState removeConnect(int fd) => _connect.remove(fd)!;

  @pragma(preferInlinePragma)
  TransportEventState getInboundRead(int bufferId) => _inboundRead[bufferId];

  @pragma(preferInlinePragma)
  TransportEventState getInboundWrite(int bufferId) => _inboundWrite[bufferId];

  @pragma(preferInlinePragma)
  TransportEventState getOutboundRead(int bufferId) => _outboundRead[bufferId];

  @pragma(preferInlinePragma)
  TransportEventState getOutboundWrite(int bufferId) => _outboundWrite[bufferId];
}
