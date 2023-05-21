import 'constants.dart';

class TransportLinks {
  final _links = <int>[];

  TransportLinks(int count) {
    for (var index = 0; index < count; index++) {
      _links.add(transportBufferUsed);
    }
  }

  @pragma(preferInlinePragma)
  int get(int bufferId) => _links[bufferId];

  @pragma(preferInlinePragma)
  int set(int bufferId, int lastBufferId) => _links[bufferId] = lastBufferId;

  @pragma(preferInlinePragma)
  Iterable<int> select(int lastBufferId) => _links.where((element) => element == lastBufferId);
}
