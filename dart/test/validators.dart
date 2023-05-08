import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'generators.dart';

class Validators {
  Validators._();

  static final _decoder = Utf8Decoder();

  static void request(Uint8List actual) {
    final expected = Generators.request();
    if (!actual._equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void response(Uint8List actual) {
    final expected = Generators.response();
    if (!actual._equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void requestsOrdered(Iterable<Uint8List> actual) {
    final expected = Generators.requestsOrdered(actual.length);
    if (!actual._equals(expected)) throw TestFailure("actual = ${_decoder._convertMany(actual)}\nexpected = ${_decoder._convertMany(expected)}");
  }

  static void requestsSumOrdered(Uint8List actual, int count) {
    final expected = Generators.requestsSumOrdered(count);
    if (!actual._equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void responsesSumOrdered(Uint8List actual, int count) {
    final expected = Generators.responsesSumOrdered(count);
    if (!actual._equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void responsesUnorderedSum(Uint8List actual, int count) {
    final expected = Generators.responsesSumUnordered(count);
    if (!actual._equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }
}

extension on Utf8Decoder {
  List<String> _convertMany(Iterable<Uint8List> bytes) => bytes.map(convert).toList();
}

extension on Uint8List {
  bool _equals(Uint8List bytes) {
    if (length != bytes.length) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      if (this[i] != bytes[i]) {
        return false;
      }
    }
    return true;
  }
}

extension on Iterable<Uint8List> {
  bool _equals(Iterable<Uint8List> bytes) {
    if (length != bytes.length) return false;
    for (var i = 0; i < length; i++) {
      if (!this.toList()[i]._equals(bytes.toList()[i])) return false;
    }
    return true;
  }
}
