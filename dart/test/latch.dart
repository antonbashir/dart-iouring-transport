import 'dart:async';

class Latch {
  var _counter = 0;
  final int limit;
  final Completer _completer = Completer();

  Latch(this.limit);

  void countDown() {
    if (++_counter == limit) _completer.complete();
  }

  Future<void> done() => _completer.future;
}
