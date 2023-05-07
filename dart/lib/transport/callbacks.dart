import 'dart:async';

import 'channel.dart';
import 'client/client.dart';
import 'constants.dart';

class TransportCallbacks {
  final _connect = <int, Completer<TransportClient>>{};
  final _accept = <int, void Function(TransportChannel channel)>{};
  final _custom = <int, Completer<int>>{};
  final _inboundBuffers = <Completer<void>>[];
  final _outboundBuffers = <Completer<void>>[];

  TransportCallbacks(int inboundBuffersCount, int outboundBuffersCount) {
    for (var index = 0; index < inboundBuffersCount; index++) {
      _inboundBuffers.add(Completer());
    }

    for (var index = 0; index < outboundBuffersCount; index++) {
      _outboundBuffers.add(Completer());
    }
  }

  @pragma(preferInlinePragma)
  void setConnect(int fd, Completer<TransportClient> completer) => _connect[fd] = completer;

  @pragma(preferInlinePragma)
  void setAccept(int fd, void Function(TransportChannel channel) onAccept) => _accept[fd] = onAccept;

  @pragma(preferInlinePragma)
  void setOutbound(int bufferId, Completer<void> completer) => _outboundBuffers[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setInbound(int bufferId, Completer<void> completer) => _inboundBuffers[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setCustom(int id, Completer<int> completer) => _custom[id] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connect.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyAccept(int fd, TransportChannel channel) => _accept[fd]!(channel);

  @pragma(preferInlinePragma)
  void notifyInbound(int bufferId) => _inboundBuffers[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyInboundError(int bufferId, Exception error) {
    final callback = _inboundBuffers[bufferId];
    if (!callback.isCompleted) callback.completeError(error);
  }

  @pragma(preferInlinePragma)
  void notifyCustom(int id, int data) => _custom.remove(id)?.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connect.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutbound(int bufferId) => _outboundBuffers[bufferId].complete();

  @pragma(preferInlinePragma)
  void notifyOutboundError(int bufferId, Exception error) {
    final callback = _outboundBuffers[bufferId];
    if (!callback.isCompleted) callback.completeError(error);
  }

  @pragma(preferInlinePragma)
  void removeCustom(int id) => _custom.remove(id);
}
