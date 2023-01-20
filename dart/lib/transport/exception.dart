class TransportException implements Exception {
  final String message;
  TransportException(this.message);

  @override
  String toString() => message;
}
