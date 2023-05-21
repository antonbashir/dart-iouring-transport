import 'dart:async';

import 'channel.dart';
import 'client/client.dart';
import 'constants.dart';

class TransportCallbacks {
  final _connect = <int, Completer<TransportClient>>{};
  final _accept = <int, void Function(TransportChannel channel)>{};
  final _custom = <int, Completer<int>>{};
  final _buffers = <Completer<int>>[];
  final _stub = Completer<int>();

  TransportCallbacks(int buffersCount) {
    for (var index = 0; index < buffersCount; index++) {
      _buffers.add(_stub);
    }
  }

  @pragma(preferInlinePragma)
  void setConnect(int fd, Completer<TransportClient> completer) => _connect[fd] = completer;

  @pragma(preferInlinePragma)
  void setAccept(int fd, void Function(TransportChannel channel) onAccept) => _accept[fd] = onAccept;

  @pragma(preferInlinePragma)
  void setOutbound(int bufferId, Completer<int> completer) => _buffers[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setData(int bufferId, Completer<int> completer) => _buffers[bufferId] = completer;

  @pragma(preferInlinePragma)
  void setCustom(int id, Completer<int> completer) => _custom[id] = completer;

  @pragma(preferInlinePragma)
  void notifyConnect(int fd, TransportClient client) => _connect.remove(fd)!.complete(client);

  @pragma(preferInlinePragma)
  void notifyAccept(int fd, TransportChannel channel) => _accept[fd]!(channel);

  @pragma(preferInlinePragma)
  void notifyData(int bufferId) {
    final callback = _buffers[bufferId];
    callback.complete(bufferId);
    _buffers[bufferId] = _stub;
  }

  @pragma(preferInlinePragma)
  void notifyDataError(int bufferId, Exception error) {
    final callback = _buffers[bufferId];
    if (!callback.isCompleted) callback.completeError(error);
  }

  @pragma(preferInlinePragma)
  void notifyCustom(int id, int data) => _custom.remove(id)?.complete(data);

  @pragma(preferInlinePragma)
  void notifyConnectError(int fd, Exception error) => _connect.remove(fd)!.completeError(error);

  @pragma(preferInlinePragma)
  void removeCustom(int id) => _custom.remove(id);
}
