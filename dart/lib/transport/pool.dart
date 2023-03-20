import 'dart:async';

class TransportPool<T> {
  final List<T> _objects;
  var _next = 0;

  TransportPool(this._objects);

  T select() {
    final client = _objects[_next];
    if (++_next == _objects.length) _next = 0;
    return client;
  }

  void add(T object) => _objects.add(object);

  void forEach(FutureOr<void> Function(T object) action) => _objects.forEach(action);

  Iterable<Future<M>> map<M>(Future<M> Function(T object) mapper) => _objects.map(mapper);
}
