import 'dart:async';

import 'channels.dart';
import 'client.dart';
import 'constants.dart';

class Transportcallbacks {
  final _connect = <int, Completer<TransportClient>>{};
  final _accept = <int, StreamController<TransportChannel>>{};
  final _inboundRead = <Completer<void>>[];
  final _inboundWrite = <Completer<void>>[];
  final _outboundRead = <Completer<void>>[];
  final _outboundWrite = <Completer<void>>[];
  final _custom = <int, Completer<int>>{};

  Transportcallbacks(int inboundBuffersCount, int outboundBuffersCount) {
    for (var index = 0; index < inboundBuffersCount; index++) {
      _inboundRead.add(Completer());
      _inboundWrite.add(Completer());
    }

    for (var index = 0; index < outboundBuffersCount; index++) {
      _outboundRead.add(Completer());
      _outboundWrite.add(Completer());
    }
  }

  @pragma(preferInlinePragma)
  void setConnect(int fd, Completer<TransportClient> completer) => _connect[fd] = completer;

  @pragma(preferInlinePragma)
  void setAccept(int fd, StreamController<TransportChannel> controller) => _accept[fd] = controller;

  @pragma(preferInlinePragma)
  void setOutboundRead(int bufferId, Completer<void> completer) => _outboundRead[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setOutboundWrite(int bufferId, Completer<void> completer) => _outboundWrite[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setInboundRead(int bufferId, Completer<void> completer) => _inboundRead[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setInboundWrite(int bufferId, Completer<void> completer) => _inboundWrite[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setCustom(int id, Completer<int> completer) => _custom[id] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connect[fd]!.complete(client);

  @pragma(preferInlinePragma)
  void notifyAccept(int fd, TransportChannel channel) => _accept[fd]!.add(channel);

  @pragma(preferInlinePragma)
  void notifyInboundRead(int bufferId) => _inboundRead[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyInboundReadError(int bufferId, Exception error) => _inboundRead[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyInboundWrite(int bufferId) => _inboundWrite[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyInboundWriteError(int bufferId, Exception error) => _inboundWrite[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundRead(int bufferId) => _outboundRead[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyOutboundWrite(int bufferId) => _outboundWrite[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyCustom(int id, int data) => _custom[id]!.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connect[fd]!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundReadError(int bufferId, Exception error) => _outboundRead[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundWriteError(int bufferId, Exception error) => _outboundWrite[bufferId].completeError(error);
}
