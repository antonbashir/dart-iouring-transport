import 'package:iouring_transport/transport/constants.dart';

class TransportLinks {
  final _inboundLinks = <int>[];
  final _outboundLinks = <int>[];

  TransportLinks(int inboundBuffersCount, int outboundBuffersCount) {
    for (var index = 0; index < inboundBuffersCount; index++) {
      _inboundLinks.add(transportBufferUsed);
    }

    for (var index = 0; index < outboundBuffersCount; index++) {
      _outboundLinks.add(transportBufferUsed);
    }
  }

  @pragma(preferInlinePragma)
  int getInbound(int bufferId) => _inboundLinks[bufferId];

  @pragma(preferInlinePragma)
  int setInbound(int bufferId, int lastBufferId) => _inboundLinks[bufferId] = lastBufferId;

  @pragma(preferInlinePragma)
  int getOutbound(int bufferId) => _outboundLinks[bufferId];

  @pragma(preferInlinePragma)
  int setOutbound(int bufferId, int lastBufferId) => _outboundLinks[bufferId] = lastBufferId;
}
