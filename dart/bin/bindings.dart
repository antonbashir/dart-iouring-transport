import 'dart:io';

void main() {
  Process.runSync("dart", ["run", "ffigen"]);
  final file = File("lib/transport/bindings.dart");
  var content = file.readAsStringSync();
  content = content.replaceAll(
    "external ffi.Pointer<small_mempool> small_mempool",
    "// external ffi.Pointer<small_mempool> small_mempool",
  );
  content = content.replaceAll(
    "external ffi.Pointer<mempool> mempool",
    "// external ffi.Pointer<mempool> mempool",
  );
  content = content.replaceAll(
    "external ffi.Pointer<quota> quota",
    "// external ffi.Pointer<quota> quota",
  );
  content = content.replaceAll(
    "final class io_uring_cqe extends ffi.Opaque {}",
    "final class io_uring_cqe extends ffi.Struct {@ffi.UnsignedLongLong()external int user_data; @ffi.Int() external int res; @ffi.UnsignedInt()external int flags;}",
  );
  file.writeAsStringSync(content);
}
