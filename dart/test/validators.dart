import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'generators.dart';

class Validators {
  Validators._();

  static final _decoder = Utf8Decoder();

  static void request(Uint8List actual) {
    final expected = Generators.request();
    if (!actual.equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void response(Uint8List actual) {
    final expected = Generators.response();
    if (!actual.equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void requests(Iterable<Uint8List> actual) {
    final expected = Generators.requests(actual.length);
    if (!actual.equals(expected)) throw TestFailure("actual = ${_decoder.convertMany(actual)}\nexpected = ${_decoder.convertMany(expected)}");
  }

  static void requestsSum(Uint8List actual, int count) {
    final expected = Generators.requestsSum(count);
    if (!actual.equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void responsesSum(Uint8List actual, int count) {
    final expected = Generators.responsesSum(count);
    if (!actual.equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }

  static void responsesUnorderedSum(Uint8List actual, int count) {
    final expected = Generators.responsesSumUnordered(count);
    if (!actual.equals(expected)) throw TestFailure("actual = ${_decoder.convert(actual)}\nexpected = ${_decoder.convert(expected)}");
  }
}

extension on Utf8Decoder {
  List<String> convertMany(Iterable<Uint8List> bytes) => bytes.map(convert).toList();
}

extension on Uint8List {
  bool equals(Uint8List bytes) {
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
  bool equals(Iterable<Uint8List> bytes) {
    if (length != bytes.length) return false;
    for (var i = 0; i < length; i++) {
      if (!this.toList()[i].equals(bytes.toList()[i])) return false;
    }
    return true;
  }
}
