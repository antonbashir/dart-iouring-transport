// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `package:ffigen`.
import 'dart:ffi' as ffi;

/// Bindings for Transport
class TransportBindings {
  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
      _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  TransportBindings(ffi.DynamicLibrary dynamicLibrary)
      : _lookup = dynamicLibrary.lookup;

  /// The symbols are looked up with [lookup].
  TransportBindings.fromLookup(
      ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName)
          lookup)
      : _lookup = lookup;

  void test() {
    return _test();
  }

  late final _testPtr =
      _lookup<ffi.NativeFunction<ffi.Void Function()>>('test');
  late final _test = _testPtr.asFunction<void Function()>();

  late final addresses = _SymbolAddresses(this);
}

class _SymbolAddresses {
  final TransportBindings _library;
  _SymbolAddresses(this._library);
  ffi.Pointer<ffi.NativeFunction<ffi.Void Function()>> get test =>
      _library._testPtr;
}
