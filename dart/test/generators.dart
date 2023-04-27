import 'dart:convert';
import 'dart:typed_data';

class Generators {
  Generators._();
  static final _encoder = Utf8Encoder();
  static Uint8List request() => _encoder.convert("request");
  static Uint8List response() => _encoder.convert("response");
  static List<Uint8List> requestsOrdered(int count) => List.generate(count, (index) => _encoder.convert("request-$index"));
  static List<Uint8List> responsesOrdered(int count) => List.generate(count, (index) => _encoder.convert("response-$index"));
  static List<Uint8List> requestsUnordered(int count) => List.generate(count, (index) => _encoder.convert("request"));
  static List<Uint8List> responsesUnordered(int count) => List.generate(count, (index) => _encoder.convert("response"));
  static Uint8List requestsSumOrdered(int count) => requestsOrdered(count).reduce((value, element) => Uint8List.fromList(value + element));
  static Uint8List responsesSumOrdered(int count) => responsesOrdered(count).reduce((value, element) => Uint8List.fromList(value + element));
  static Uint8List requestsSumUnordered(int count) => requestsUnordered(count).reduce((value, element) => Uint8List.fromList(value + element));
  static Uint8List responsesSumUnordered(int count) => responsesUnordered(count).reduce((value, element) => Uint8List.fromList(value + element));
}
