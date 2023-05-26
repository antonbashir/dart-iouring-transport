import 'dart:async';

class Latch {
  var _counter = 0;
  final int _limit;
  final Completer _completer = Completer();

  Latch(this._limit);

  void countDown() {
    if (++_counter == _limit) _completer.complete();
  }

  Future<void> done() => _completer.future;
}
