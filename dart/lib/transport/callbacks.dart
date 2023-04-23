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
  final _inboundSequences = <Completer<void>>[];
  final _outboundSequences = <Completer<void>>[];

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
  void setOutboundBuffer(int bufferId, Completer<int> completer) => _outboundBuffers[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setInboundBuffer(int bufferId, Completer<int> completer) => _inboundBuffers[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setCustom(int id, Completer<int> completer) => _custom[id] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connect.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyAccept(int fd, TransportChannel channel) => _accept[fd]!(channel);

  @pragma(preferInlinePragma)
  void notifyInboundBuffer(int bufferId, int length) => _inboundBuffers[bufferId].complete(length);

  @pragma(preferInlinePragma)
  void notifyInboundBufferError(int bufferId, Exception error) => _inboundBuffers[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void notifyCustom(int id, int data) => _custom.remove(id)?.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connect.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  void notifyOutboundBuffer(int bufferId, int length) => _outboundBuffers[bufferId].complete(length);

  @pragma(preferInlinePragma)
  void notifyOutboundBufferError(int bufferId, Exception error) => _outboundBuffers[bufferId].completeError(error);

  @pragma(preferInlinePragma)
  void removeCustom(int id) => _custom.remove(id);
}
