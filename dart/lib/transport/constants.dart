import 'bindings.dart';

const preferInlinePragma = "vm:prefer-inline";

const empty = "";
const unknown = "unknown";
const newLine = "\n";
const slash = "/";
const dot = ".";
const star = "*";
const equalSpaced = " = ";
const openingBracket = "{";
const closingBracket = "}";
const comma = ",";
const parentDirectorySymbol = '..';
const currentDirectorySymbol = './';

const transportLibraryName = "libtransport.so";
const transportPackageName = "iouring_transport";

const int32Max = 4294967295;

const packageConfigJsonFile = "package_config.json";

String loadError(path) => "Unable to load library ${path}";

const unableToFindProjectRoot = "Unable to find project root";

const dlCloseFunction = 'dlclose';

const pubspecYamlFile = 'pubspec.yaml';
const pubspecYmlFile = 'pubspec.yml';

const defaultJobName = "job";

class Directories {
  const Directories._();

  static const native = "/native";
  static const package = "/package";
  static const dotDartTool = ".dart_tool";
}

class Messages {
  const Messages._();

  static const runPubGet = "Run 'dart pub get'";
  static const specifyDartEntryPoint = 'Specify dart execution entry point';
  static const projectRootNotFound = "Project root not found (parent of 'pubspec.yaml')";
  static const nativeSourcesNotFound = "Native root does not contain any *.c or *.cpp sources";
}

class FileExtensions {
  const FileExtensions._();

  static const exe = "exe";
  static const so = "so";
  static const h = "h";
  static const c = "c";
  static const cpp = "cpp";
  static const hpp = "hpp";
  static const tarGz = "tar.gz";
}

class CompileOptions {
  const CompileOptions._();

  static const dartExecutable = "dart";
  static const tarExecutable = "tar";
  static const tarOption = "-czf";
  static const compileCommand = "compile";
  static const outputOption = "-o";
  static const gccExecutable = "gcc";
  static const gccSharedOption = "-shared";
  static const gccFpicOption = "-fPIC";
}

class PackageConfigFields {
  PackageConfigFields._();

  static const rootUri = 'rootUri';
  static const name = 'name';
  static const packages = 'packages';
}

enum TransportLogLevel {
  trace,
  debug,
  info,
  warn,
  error,
  fatal,
}

const transportLogLevels = [
  "TRACE",
  "DEBUG",
  "INFO",
  "WARN",
  "ERROR",
  "FATAL",
];

const transportBufferUsed = -1;

const transportEventRead = 1 << 0;
const transportEventWrite = 1 << 1;
const transportEventReceiveMessage = 1 << 2;
const transportEventSendMessage = 1 << 3;
const transportEventAccept = 1 << 4;
const transportEventConnect = 1 << 5;
const transportEventClient = 1 << 6;
const transportEventFile = 1 << 7;
const transportEventServer = 1 << 8;
const transportEventCustom = 1 << 9;
const transportEventLink = 1 << 10;

const transportEventAll = transportEventRead |
    transportEventWrite |
    transportEventAccept |
    transportEventConnect |
    transportEventReceiveMessage |
    transportEventSendMessage |
    transportEventClient |
    transportEventFile |
    transportEventServer |
    transportEventCustom |
    transportEventLink;

const ringSetupIopoll = 1 << 0;
const ringSetupSqpoll = 1 << 1;
const ringSetupSqAff = 1 << 2;
const ringSetupCqsize = 1 << 3;
const ringSetupClamp = 1 << 4;
const ringSetupAttachWq = 1 << 5;
const ringSetupRDisabled = 1 << 6;
const ringSetupSubmitAll = 1 << 7;
const ringSetupCoopTaskrun = 1 << 8;
const ringSetupTaskrunFlag = 1 << 9;
const ringSetupSqe128 = 1 << 10;
const ringSetupCqe32 = 1 << 11;
const ringSetupSingleIssuer = 1 << 12;
const ringSetupDeferTaskrun = 1 << 13;

const transportSocketOptionSocketNonblock = 1 << 1;
const transportSocketOptionSocketClockexec = 1 << 2;
const transportSocketOptionSocketReuseaddr = 1 << 3;
const transportSocketOptionSocketReuseport = 1 << 4;
const transportSocketOptionSocketRcvbuf = 1 << 5;
const transportSocketOptionSocketSndbuf = 1 << 6;
const transportSocketOptionSocketBroadcast = 1 << 7;
const transportSocketOptionSocketKeepalive = 1 << 8;
const transportSocketOptionSocketRcvlowat = 1 << 9;
const transportSocketOptionSocketSndlowat = 1 << 10;
const transportSocketOptionIpTtl = 1 << 11;
const transportSocketOptionIpAddMembership = 1 << 12;
const transportSocketOptionIpAddSourceMembership = 1 << 13;
const transportSocketOptionIpDropMembership = 1 << 14;
const transportSocketOptionIpDropSourceMembership = 1 << 15;
const transportSocketOptionIpFreebind = 1 << 16;
const transportSocketOptionIpMulticastAll = 1 << 17;
const transportSocketOptionIpMulticastIf = 1 << 18;
const transportSocketOptionIpMulticastLoop = 1 << 19;
const transportSocketOptionIpMulticastTtl = 1 << 20;
const transportSocketOptionTcpQuickack = 1 << 21;
const transportSocketOptionTcpDeferAccept = 1 << 22;
const transportSocketOptionTcpFastopen = 1 << 23;
const transportSocketOptionTcpKeepidle = 1 << 24;
const transportSocketOptionTcpKeepcnt = 1 << 25;
const transportSocketOptionTcpKeepintvl = 1 << 26;
const transportSocketOptionTcpMaxseg = 1 << 27;
const transportSocketOptionTcpNoDelay = 1 << 28;
const transportSocketOptionTcpSyncnt = 1 << 29;

const transportTimeoutInfinity = -1;
const transportParentRingNone = -1;

const transportIosqeFixedFile = 1 << 0;
const transportIosqeIoDrain = 1 << 1;
const transportIosqeIoLink = 1 << 2;
const transportIosqeIoHardlink = 1 << 3;
const transportIosqeAsync = 1 << 4;
const transportIosqeBufferSelect = 1 << 5;
const transportIosqeCqeSkipSuccess = 1 << 6;

enum TransportDatagramMessageFlag {
  oob(0x01),
  peek(0x02),
  dontroute(0x04),
  tryhard(0x04),
  ctrunc(0x08),
  proxy(0x10),
  trunc(0x20),
  dontwait(0x40),
  eor(0x80),
  waitall(0x100),
  fin(0x200),
  syn(0x400),
  confirm(0x800),
  rst(0x1000),
  errqueue(0x2000),
  nosignal(0x4000),
  more(0x8000),
  waitforone(0x10000),
  batch(0x40000),
  zerocopy(0x4000000),
  fastopen(0x20000000),
  cmsgCloexec(0x40000000);

  final int flag;

  const TransportDatagramMessageFlag(this.flag);
}

enum TransportEvent {
  accept,
  connect,
  serverRead,
  serverWrite,
  clientRead,
  clientWrite,
  serverReceive,
  serverSend,
  clientReceive,
  clientSend,
  fileRead,
  fileWrite,
  serverReadLink,
  serverWriteLink,
  clientReadLink,
  clientWriteLink,
  serverReceiveLink,
  serverSendLink,
  clientReceiveLink,
  clientSendLink,
  fileReadLink,
  fileWriteLink,
  unknown;

  static TransportEvent ofEvent(int event) {
    if (event == (transportEventRead | transportEventClient)) return TransportEvent.clientRead;
    if (event == (transportEventWrite | transportEventClient)) return TransportEvent.clientWrite;
    if (event == (transportEventRead | transportEventFile)) return TransportEvent.fileRead;
    if (event == (transportEventWrite | transportEventFile)) return TransportEvent.fileWrite;
    if (event == (transportEventRead | transportEventServer)) return TransportEvent.serverRead;
    if (event == (transportEventWrite | transportEventServer)) return TransportEvent.serverWrite;
    if (event == (transportEventSendMessage | transportEventClient)) return TransportEvent.clientSend;
    if (event == (transportEventReceiveMessage | transportEventClient)) return TransportEvent.clientReceive;
    if (event == (transportEventSendMessage | transportEventServer)) return TransportEvent.serverSend;
    if (event == (transportEventReceiveMessage | transportEventServer)) return TransportEvent.serverReceive;
    if (event == (transportEventRead | transportEventClient | transportEventLink)) return TransportEvent.clientReadLink;
    if (event == (transportEventWrite | transportEventClient | transportEventLink)) return TransportEvent.clientWriteLink;
    if (event == (transportEventRead | transportEventFile | transportEventLink)) return TransportEvent.fileReadLink;
    if (event == (transportEventWrite | transportEventFile | transportEventLink)) return TransportEvent.fileWriteLink;
    if (event == (transportEventRead | transportEventServer | transportEventLink)) return TransportEvent.serverReadLink;
    if (event == (transportEventWrite | transportEventServer | transportEventLink)) return TransportEvent.serverWriteLink;
    if (event == (transportEventSendMessage | transportEventClient | transportEventLink)) return TransportEvent.clientSendLink;
    if (event == (transportEventReceiveMessage | transportEventClient | transportEventLink)) return TransportEvent.clientReceiveLink;
    if (event == (transportEventSendMessage | transportEventServer | transportEventLink)) return TransportEvent.serverSendLink;
    if (event == (transportEventReceiveMessage | transportEventServer | transportEventLink)) return TransportEvent.serverReceiveLink;
    if (event == transportEventAccept) return TransportEvent.accept;
    if (event == transportEventConnect) return TransportEvent.connect;
    return TransportEvent.unknown;
  }

  @override
  String toString() => name;
}

const transportRetryableErrorCodes = {EINTR, EAGAIN, ECANCELED};

enum TransportFileMode {
  readOnly(1 << 0),
  writeOnly(1 << 1),
  readWrite(1 << 2),
  writeOnlyAppend(1 << 3),
  readWriteAppend(1 << 4);

  final int mode;

  const TransportFileMode(this.mode);
}
