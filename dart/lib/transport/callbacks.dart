import 'dart:async';

import 'channel.dart';
import 'client/client.dart';
import 'constants.dart';

class TransportCallbacks {
  final _connect = <int, Completer<TransportClient>>{};
  final _accept = <int, void Function(TransportChannel channel)>{};
  final _custom = <int, Completer<int>>{};
  final _inboundReadEvents = <Completer<int>>[];
  final _inboundWriteEvents = <Completer<void>>[];
  final _outboundReadEvents = <Completer<int>>[];
  final _outboundWriteEvents = <Completer<void>>[];
  final _inboundReadSequences = <Completer<void>>[];
  final _inboundWriteSequences = <Completer<void>>[];
  final _outboundReadSequences = <Completer<void>>[];
  final _outboundWriteSequences = <Completer<void>>[];

  TransportCallbacks(int inboundBuffersCount, int outboundBuffersCount) {
    for (var index = 0; index < inboundBuffersCount; index++) {
      _inboundReadEvents.add(Completer());
      _inboundWriteEvents.add(Completer());
    }

    for (var index = 0; index < outboundBuffersCount; index++) {
      _outboundReadEvents.add(Completer());
      _outboundWriteEvents.add(Completer());
    }
  }

  @pragma(preferInlinePragma)
  void setConnect(int fd, Completer<TransportClient> completer) => _connect[fd] = completer;

  @pragma(preferInlinePragma)
  void setAccept(int fd, void Function(TransportChannel channel) onAccept) => _accept[fd] = onAccept;

  @pragma(preferInlinePragma)
  void setOutboundRead(int bufferId, Completer<int> completer) => _outboundReadEvents[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setOutboundWrite(int bufferId, Completer<void> completer) => _outboundWriteEvents[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setInboundRead(int bufferId, Completer<int> completer) => _inboundReadEvents[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setInboundWrite(int bufferId, Completer<void> completer) => _inboundWriteEvents[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setCustom(int id, Completer<int> completer) => _custom[id] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connect.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyAccept(int fd, TransportChannel channel) => _accept[fd]!(channel);

  @pragma(preferInlinePragma)
  void notifyInboundRead(int bufferId, int length) => _inboundReadEvents[bufferId].complete(length);

  @pragma(preferInlinePragma)
  void notifyInboundReadError(int bufferId, Exception error) => _inboundReadEvents[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyInboundWrite(int bufferId) => _inboundWriteEvents[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyInboundWriteError(int bufferId, Exception error) => _inboundWriteEvents[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundRead(int bufferId, int length) => _outboundReadEvents[bufferId].complete(length);

  @pragma(preferInlinePragma)
  void notifyOutboundWrite(int bufferId) => _outboundWriteEvents[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyCustom(int id, int data) => _custom.remove(id)?.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connect.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundReadError(int bufferId, Exception error) => _outboundReadEvents[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundWriteError(int bufferId, Exception error) => _outboundWriteEvents[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void removeCustom(int id) => _custom.remove(id);
}
