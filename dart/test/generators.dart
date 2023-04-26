import 'dart:convert';
import 'dart:typed_data';

class Generators {
  Generators._();
  static final _encoder = Utf8Encoder();
  static Uint8List request() => _encoder.convert("request");
  static Uint8List response() => _encoder.convert("response");
  static List<Uint8List> requests(int count) => List.generate(count, (index) => _encoder.convert("request-$index"));
  static List<Uint8List> responses(int count) => List.generate(count, (index) => _encoder.convert("response-$index"));
}
