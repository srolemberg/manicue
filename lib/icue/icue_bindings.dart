import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- Constants ---

/// Small string length
const int corsairStringSizeS = 64;

/// Medium string length
const int corsairStringSizeM = 128;

/// Maximum level of layer’s priority that can be used in CorsairSetLayerPriority
const int corsairLayerPriorityMax = 255;

/// Maximum number of devices to be discovered
const int corsairDeviceCountMax = 64;

/// Maximum number of LEDs controlled by device
const int corsairDeviceLedCountMax = 512;

// --- Enums with Original Native C Values & Documentation ---

/// Contains shared list of all errors which could happen during calling of Corsair* functions
enum CorsairError {
  /// If previously called function completed successfully
  ceSuccess(0),

  /// If iCUE is not running or was shut down or third-party control is disabled in iCUE settings (runtime error),
  /// or if developer did not call CorsairConnect after calling CorsairDisconnect or on app start (developer error)
  ceNotConnected(1),

  /// If some other client has or took over exclusive control (runtime error)
  ceNoControl(2),

  /// If developer is calling the function that is not supported by the server
  /// (either because protocol has broken by server or client or because the function is new and server is too old. Check CorsairSessionDetails for details) (developer error)
  ceIncompatibleProtocol(3),

  /// If developer supplied invalid arguments to the function (for specifics look at function descriptions) (developer error)
  ceInvalidArguments(4),

  /// If developer is calling the function that is not allowed due to current state
  /// (reading improper properties from device, or setting callback when it has already been set) (developer error)
  ceInvalidOperation(5),

  /// If invalid device id has been supplied as an argument to the function (when device id refers to disconnected device) (runtime error)
  ceDeviceNotFound(6),

  /// If specific functionality (key interception) is disabled in iCUE settings (runtime error)
  ceNotAllowed(7);

  final int value;
  const CorsairError(this.value);

  static CorsairError fromValue(int val) {
    return CorsairError.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairError.ceNotConnected,
    );
  }
}

/// Contains a list of all possible session states
enum CorsairSessionState {
  /// Dummy value
  cssInvalid(0),

  /// Client not initialized or client closed connection (initial state)
  cssClosed(1),

  /// Client initiated connection but not connected yet
  cssConnecting(2),

  /// Server did not respond, sdk will try again
  cssTimeout(3),

  /// Server did not allow connection
  cssConnectionRefused(4),

  /// Server closed connection
  cssConnectionLost(5),

  /// Successfully connected
  cssConnected(6);

  final int value;
  const CorsairSessionState(this.value);

  static CorsairSessionState fromValue(int val) {
    return CorsairSessionState.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairSessionState.cssInvalid,
    );
  }
}

/// Contains list of available device types
enum CorsairDeviceType {
  /// For unknown/invalid devices
  cdtUnknown(0x0000),

  /// For keyboards
  cdtKeyboard(0x0001),

  /// For mice
  cdtMouse(0x0002),

  /// For mousemats
  cdtMousemat(0x0004),

  /// For headsets
  cdtHeadset(0x0008),

  /// For headset stands
  cdtHeadsetStand(0x0010),

  /// For DIY-devices like Commander PRO
  cdtFanLedController(0x0020),

  /// For DIY-devices like Lighting Node PRO
  cdtLedController(0x0040),

  /// For memory modules
  cdtMemoryModule(0x0080),

  /// For coolers
  cdtCooler(0x0100),

  /// For motherboards
  cdtMotherboard(0x0200),

  /// For graphics cards
  cdtGraphicsCard(0x0400),

  /// For touchbars
  cdtTouchbar(0x0800),

  /// For game controllers
  cdtGameController(0x1000),

  /// For all devices
  cdtAll(0xFFFFFFFF);

  final int value;
  const CorsairDeviceType(this.value);

  static CorsairDeviceType fromValue(int val) {
    return CorsairDeviceType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairDeviceType.cdtUnknown,
    );
  }
}

/// Contains list of event identifiers
enum CorsairEventId {
  /// Dummy value
  ceiInvalid(0),

  /// Device connection status changed event identifier
  ceiDeviceConnectionStatusChangedEvent(1),

  /// Key event identifier
  ceiKeyEvent(2);

  final int value;
  const CorsairEventId(this.value);

  static CorsairEventId fromValue(int val) {
    return CorsairEventId.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairEventId.ceiInvalid,
    );
  }
}

/// Contains a shared list of G, M and S keys (not all available keys!)
enum CorsairMacroKeyId {
  cmkiInvalid(0),
  cmki1(1),
  cmki2(2),
  cmki3(3),
  cmki4(4),
  cmki5(5),
  cmki6(6),
  cmki7(7),
  cmki8(8),
  cmki9(9),
  cmki10(10),
  cmki11(11),
  cmki12(12),
  cmki13(13),
  cmki14(14),
  cmki15(15),
  cmki16(16),
  cmki17(17),
  cmki18(18),
  cmki19(19),
  cmki20(20);

  final int value;
  const CorsairMacroKeyId(this.value);

  static CorsairMacroKeyId fromValue(int val) {
    return CorsairMacroKeyId.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairMacroKeyId.cmkiInvalid,
    );
  }
}

/// Contains list of properties identifiers which can be read from device
enum CorsairDevicePropertyId {
  cdpiInvalid(0),

  /// Array of CorsairDevicePropertyId members supported by device
  cdpiPropertyArray(1),

  /// Indicates Mic state (On or Off); used for headset, headset stand
  cdpiMicEnabled(2),

  /// Indicates Surround Sound state (On or Off); used for headset, headset stand
  cdpiSurroundSoundEnabled(3),

  /// Indicates Sidetone state (On or Off); used for headset (where applicable)
  cdpiSidetoneEnabled(4),

  /// The number of active equalizer preset (integer, 1 - 5); used for headset, headset stand
  cdpiEqualizerPreset(5),

  /// Keyboard physical layout (see CorsairPhysicalLayout for valid values); used for keyboard
  cdpiPhysicalLayout(6),

  /// Keyboard logical layout (see CorsairLogicalLayout for valid values); used for keyboard
  cdpiLogicalLayout(7),

  /// Array of programmable G, M or S keys on device
  cdpiMacroKeyArray(8),

  /// Battery level (0 - 100); used for wireless devices
  cdpiBatteryLevel(9),

  /// Total number of LEDs connected to the channel
  cdpiChannelLedCount(10),

  /// Number of LED-devices (fans, strips, etc.) connected to the channel which is controlled by the DIY device
  cdpiChannelDeviceCount(11),

  /// Array of integers, each element describes the number of LEDs controlled by the channel device
  cdpiChannelDeviceLedCountArray(12),

  /// Array of CorsairChannelDeviceType members, each element describes the type of the channel device
  cdpiChannelDeviceTypeArray(13);

  final int value;
  const CorsairDevicePropertyId(this.value);

  static CorsairDevicePropertyId fromValue(int val) {
    return CorsairDevicePropertyId.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairDevicePropertyId.cdpiInvalid,
    );
  }
}

/// Contains list of available property types
enum CorsairDataType {
  /// For property of type Boolean
  ctBoolean(0),

  /// For property of type Int32 or Enumeration
  ctInt32(1),

  /// For property of type Float64
  ctFloat64(2),

  /// For property of type String
  ctString(3),

  /// For array of Boolean
  ctBooleanArray(16),

  /// For array of Int32
  ctInt32Array(17),

  /// For array of Float64
  ctFloat64Array(18),

  /// For array of String
  ctStringArray(19);

  final int value;
  const CorsairDataType(this.value);

  static CorsairDataType fromValue(int val) {
    return CorsairDataType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairDataType.ctBoolean,
    );
  }
}

/// Contains list of operations that can be applied to the property
abstract class CorsairPropertyFlag {
  static const int cpfNone = 0x00;

  /// Describes readable property
  static const int cpfCanRead = 0x01;

  /// Describes writable property
  static const int cpfCanWrite = 0x02;

  /// If flag is set, then index should be used to read/write multiple properties that share the same property identifier
  static const int cpfIndexed = 0x04;
}

/// Contains list of available physical layouts for keyboards
enum CorsairPhysicalLayout {
  cplInvalid(0),
  cplUS(1),
  cplUK(2),
  cplJP(3),
  cplKR(4),
  cplBR(5);

  final int value;
  const CorsairPhysicalLayout(this.value);

  static CorsairPhysicalLayout fromValue(int val) {
    return CorsairPhysicalLayout.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairPhysicalLayout.cplInvalid,
    );
  }
}

/// Contains list of available logical layouts for keyboards
enum CorsairLogicalLayout {
  cllInvalid(0),
  cllUsInt(1),
  cllNa(2),
  cllEu(3),
  cllUk(4),
  cllBe(5),
  cllBr(6),
  cllCh(7),
  cllCn(8),
  cllDe(9),
  cllEs(10),
  cllFr(11),
  cllIt(12),
  cllNd(13),
  cllRu(14),
  cllJp(15),
  cllKr(16),
  cllTw(17),
  cllMex(18);

  final int value;
  const CorsairLogicalLayout(this.value);

  static CorsairLogicalLayout fromValue(int val) {
    return CorsairLogicalLayout.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairLogicalLayout.cllInvalid,
    );
  }
}

/// Contains list of the LED-devices which can be connected to the DIY-device, memory module or cooler
enum CorsairChannelDeviceType {
  ccdtInvalid(0),
  ccdtHdFan(1),
  ccdtSpFan(2),
  ccdtLlFan(3),
  ccdtMlFan(4),
  ccdtQlFan(5),
  ccdt8LedSeriesFan(6),
  ccdtStrip(7),
  ccdtDap(8),
  ccdtPump(9),
  ccdtDram(10),
  ccdtWaterBlock(11),
  ccdtQxFan(12);

  final int value;
  const CorsairChannelDeviceType(this.value);

  static CorsairChannelDeviceType fromValue(int val) {
    return CorsairChannelDeviceType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairChannelDeviceType.ccdtInvalid,
    );
  }
}

/// Contains list of available SDK access levels
enum CorsairAccessLevel {
  /// Shared mode (default)
  calShared(0),

  /// Exclusive lightings, but shared events
  calExclusiveLightingControl(1),

  /// Exclusive key events, but shared lightings
  calExclusiveKeyEventsListening(2),

  /// Exclusive mode
  calExclusiveLightingControlAndKeyEventsListening(3);

  final int value;
  const CorsairAccessLevel(this.value);

  static CorsairAccessLevel fromValue(int val) {
    return CorsairAccessLevel.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairAccessLevel.calShared,
    );
  }
}

/// Contains a list of led groups. Led group is used as a part of led identifier
enum CorsairLedGroup {
  /// For keyboard leds
  clgKeyboard(0),

  /// For keyboard leds on G keys
  clgKeyboardGKeys(1),

  /// For keyboard lighting pipe leds
  clgKeyboardEdge(2),

  /// For vendor specific keyboard leds (ProfileSwitch, DialRing, etc.)
  clgKeyboardOem(3),

  /// For mouse leds
  clgMouse(4),

  /// For mousemat leds
  clgMousemat(5),

  /// For headset leds
  clgHeadset(6),

  /// For headset stand leds
  clgHeadsetStand(7),

  /// For memory module leds
  clgMemoryModule(8),

  /// For motherboard leds
  clgMotherboard(9),

  /// For graphics card leds
  clgGraphicsCard(10),

  /// For leds on the first channel of DIY devices and coolers
  clgDiyChannel1(11),

  /// For leds on the second channel of DIY devices and coolers
  clgDiyChannel2(12),

  /// For leds on the third channel of DIY devices and coolers
  clgDiyChannel3(13),

  /// For touchbar leds
  clgTouchbar(14),

  /// For game controller leds
  clgGameController(15);

  final int value;
  const CorsairLedGroup(this.value);

  static CorsairLedGroup fromValue(int val) {
    return CorsairLedGroup.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairLedGroup.clgKeyboard,
    );
  }
}

/// Contains a list of keyboard leds that belong to CLG_Keyboard group
enum CorsairLedIdKeyboard {
  clkInvalid(0),
  clkEscape(1),
  clkF1(2),
  clkF2(3),
  clkF3(4),
  clkF4(5),
  clkF5(6),
  clkF6(7),
  clkF7(8),
  clkF8(9),
  clkF9(10),
  clkF10(11),
  clkF11(12),
  clkF12(13),
  clkGraveAccentAndTilde(14),
  clk1(15),
  clk2(16),
  clk3(17),
  clk4(18),
  clk5(19),
  clk6(20),
  clk7(21),
  clk8(22),
  clk9(23),
  clk0(24),
  clkMinusAndUnderscore(25),
  clkEqualsAndPlus(26),
  clkBackspace(27),
  clkTab(28),
  clkQ(29),
  clkW(30),
  clkE(31),
  clkR(32),
  clkT(33),
  clkY(34),
  clkU(35),
  clkI(36),
  clkO(37),
  clkP(38),
  clkBracketLeft(39),
  clkBracketRight(40),
  clkCapsLock(41),
  clkA(42),
  clkS(43),
  clkD(44),
  clkF(45),
  clkG(46),
  clkH(47),
  clkJ(48),
  clkK(49),
  clkL(50),
  clkSemicolonAndColon(51),
  clkApostropheAndDoubleQuote(52),
  clkBackslash(53),
  clkEnter(54),
  clkLeftShift(55),
  clkNonUsBackslash(56),
  clkZ(57),
  clkX(58),
  clkC(59),
  clkV(60),
  clkB(61),
  clkN(62),
  clkM(63),
  clkCommaAndLessThan(64),
  clkPeriodAndBiggerThan(65),
  clkSlashAndQuestionMark(66),
  clkRightShift(67),
  clkLeftCtrl(68),
  clkLeftGui(69),
  clkLeftAlt(70),
  clkSpace(71),
  clkRightAlt(72),
  clkRightGui(73),
  clkApplication(74),
  clkRightCtrl(75),
  clkLedProgramming(76),
  clkLang1(77),
  clkLang2(78),
  clkInternational1(79),
  clkInternational2(80),
  clkInternational3(81),
  clkInternational4(82),
  clkInternational5(83),
  clkPrintScreen(84),
  clkScrollLock(85),
  clkPauseBreak(86),
  clkInsert(87),
  clkHome(88),
  clkPageUp(89),
  clkDelete(90),
  clkEnd(91),
  clkPageDown(92),
  clkUpArrow(93),
  clkLeftArrow(94),
  clkDownArrow(95),
  clkRightArrow(96),
  clkNonUsTilde(97),
  clkBrightness(98),
  clkWinLock(99),
  clkMute(100),
  clkStop(101),
  clkScanPreviousTrack(102),
  clkPlayPause(103),
  clkScanNextTrack(104),
  clkNumLock(105),
  clkKeypadSlash(106),
  clkKeypadAsterisk(107),
  clkKeypadMinus(108),
  clkKeypad7(109),
  clkKeypad8(110),
  clkKeypad9(111),
  clkKeypadPlus(112),
  clkKeypad4(113),
  clkKeypad5(114),
  clkKeypad6(115),
  clkKeypad1(116),
  clkKeypad2(117),
  clkKeypad3(118),
  clkKeypadComma(119),
  clkKeypadEnter(120),
  clkKeypad0(121),
  clkKeypadPeriodAndDelete(122),
  clkVolumeUp(123),
  clkVolumeDown(124),
  clkMr(125),
  clkM1(126),
  clkM2(127),
  clkM3(128),
  clkFn(129);

  final int value;
  const CorsairLedIdKeyboard(this.value);

  static CorsairLedIdKeyboard fromValue(int val) {
    return CorsairLedIdKeyboard.values.firstWhere(
      (e) => e.value == val,
      orElse: () => CorsairLedIdKeyboard.clkInvalid,
    );
  }
}

// --- FFI Structs ---

/// Contains information about version that consists of three components
final class CorsairVersion extends Struct {
  @Int32()
  external int major;

  @Int32()
  external int minor;

  @Int32()
  external int patch;
}

/// Contains information about SDK and iCUE versions
final class CorsairSessionDetails extends Struct {
  /// Version of SDK client
  external CorsairVersion clientVersion;

  /// Version of SDK server
  external CorsairVersion serverVersion;

  /// Version of iCUE
  external CorsairVersion serverHostVersion;
}

/// Contains information about session state and client/server versions
final class CorsairSessionStateChanged extends Struct {
  @Int32()
  external int state;

  external CorsairSessionDetails details;
}

/// Contains information about device
final class CorsairDeviceInfo extends Struct {
  @Int32()
  external int type;

  @Array(128)
  external Array<Int8> id;

  @Array(128)
  external Array<Int8> serial;

  @Array(128)
  external Array<Int8> model;

  @Int32()
  external int ledCount;

  @Int32()
  external int channelCount;

  String _readStringFromArray(Array<Int8> array, int maxLength) {
    final codeUnits = <int>[];
    for (var i = 0; i < maxLength; i++) {
      final byte = array[i];
      if (byte == 0) break;
      codeUnits.add(byte);
    }
    return utf8.decode(codeUnits);
  }

  String get idString => _readStringFromArray(id, 128);
  String get serialString => _readStringFromArray(serial, 128);
  String get modelString => _readStringFromArray(model, 128);
}

/// Contains led id and position of led
final class CorsairLedPosition extends Struct {
  @Uint32()
  external int id;

  @Double()
  external double cx;

  @Double()
  external double cy;
}

/// Contains device search filter
final class CorsairDeviceFilter extends Struct {
  @Int32()
  external int deviceTypeMask;
}

/// Contains information about device that was connected or disconnected
final class CorsairDeviceConnectionStatusChangedEvent extends Struct {
  @Array(128)
  external Array<Int8> deviceId;

  @Bool()
  external bool isConnected;

  String get deviceIdString {
    final codeUnits = <int>[];
    for (var i = 0; i < 128; i++) {
      final byte = deviceId[i];
      if (byte == 0) break;
      codeUnits.add(byte);
    }
    return utf8.decode(codeUnits);
  }
}

/// Contains information about device where G, M or S key was pressed/released and the key itself
final class CorsairKeyEvent extends Struct {
  @Array(128)
  external Array<Int8> deviceId;

  @Int32()
  external int keyId;

  @Bool()
  external bool isPressed;

  String get deviceIdString {
    final codeUnits = <int>[];
    for (var i = 0; i < 128; i++) {
      final byte = deviceId[i];
      if (byte == 0) break;
      codeUnits.add(byte);
    }
    return utf8.decode(codeUnits);
  }
}

/// Contains information about event id and event data
final class CorsairEvent extends Struct {
  @Int32()
  external int id;

  external Pointer<Void> eventDataUnion;
}

/// Represents an array of boolean values
final class CorsairDataTypeBooleanArray extends Struct {
  external Pointer<Bool> items;
  @Uint32()
  external int count;
}

/// Represents an array of integer values
final class CorsairDataTypeInt32Array extends Struct {
  external Pointer<Int32> items;
  @Uint32()
  external int count;
}

/// Represents an array of double values
final class CorsairDataTypeFloat64Array extends Struct {
  external Pointer<Double> items;
  @Uint32()
  external int count;
}

/// Represents an array of pointers to null terminated strings
final class CorsairDataTypeStringArray extends Struct {
  external Pointer<Pointer<Utf8>> items;
  @Uint32()
  external int count;
}

/// A union of all property data types
final class CorsairDataValue extends Union {
  @Bool()
  external bool boolean;

  @Int32()
  external int int32;

  @Double()
  external double float64;

  external Pointer<Utf8> string;

  external CorsairDataTypeBooleanArray booleanArray;
  external CorsairDataTypeInt32Array intArray;
  external CorsairDataTypeFloat64Array floatArray;
  external CorsairDataTypeStringArray stringArray;
}

/// Contains information about device property type and value
final class CorsairProperty extends Struct {
  @Int32()
  external int type;

  external CorsairDataValue value;
}

/// Contains information about LED and its color
final class CorsairLedColor extends Struct {
  @Uint32()
  external int id;

  @Uint8()
  external int r;

  @Uint8()
  external int g;

  @Uint8()
  external int b;

  @Uint8()
  external int a;
}

/// Contains information about key event configuration
final class CorsairKeyEventConfiguration extends Struct {
  @Int32()
  external int keyId;

  @Bool()
  external bool isIntercepted;
}

// --- Callback Typedefs ---
typedef CorsairSessionStateChangedNative = Void Function(
    Pointer<Void> context, Pointer<CorsairSessionStateChanged> eventData);
typedef CorsairSessionStateChangedDart = void Function(
    Pointer<Void> context, Pointer<CorsairSessionStateChanged> eventData);

typedef CorsairAsyncCallbackNative = Void Function(
    Pointer<Void> context, Int32 error);
typedef CorsairAsyncCallbackDart = void Function(
    Pointer<Void> context, int error);

typedef CorsairEventHandlerNative = Void Function(
    Pointer<Void> context, Pointer<CorsairEvent> event);
typedef CorsairEventHandlerDart = void Function(
    Pointer<Void> context, Pointer<CorsairEvent> event);

// --- Native Function Signatures ---

typedef CorsairConnectNative = Int32 Function(
    Pointer<NativeFunction<CorsairSessionStateChangedNative>> onStateChanged,
    Pointer<Void> context);
typedef CorsairConnectDart = int Function(
    Pointer<NativeFunction<CorsairSessionStateChangedNative>> onStateChanged,
    Pointer<Void> context);

typedef CorsairDisconnectNative = Int32 Function();
typedef CorsairDisconnectDart = int Function();

typedef CorsairGetSessionDetailsNative = Int32 Function(
    Pointer<CorsairSessionDetails> details);
typedef CorsairGetSessionDetailsDart = int Function(
    Pointer<CorsairSessionDetails> details);

typedef CorsairGetDevicesNative = Int32 Function(
    Pointer<CorsairDeviceFilter> filter,
    Int32 sizeMax,
    Pointer<CorsairDeviceInfo> devices,
    Pointer<Int32> size);
typedef CorsairGetDevicesDart = int Function(
    Pointer<CorsairDeviceFilter> filter,
    int sizeMax,
    Pointer<CorsairDeviceInfo> devices,
    Pointer<Int32> size);

typedef CorsairGetDeviceInfoNative = Int32 Function(
    Pointer<Utf8> deviceId, Pointer<CorsairDeviceInfo> deviceInfo);
typedef CorsairGetDeviceInfoDart = int Function(
    Pointer<Utf8> deviceId, Pointer<CorsairDeviceInfo> deviceInfo);

typedef CorsairGetLedPositionsNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 sizeMax,
    Pointer<CorsairLedPosition> ledPositions,
    Pointer<Int32> size);
typedef CorsairGetLedPositionsDart = int Function(
    Pointer<Utf8> deviceId,
    int sizeMax,
    Pointer<CorsairLedPosition> ledPositions,
    Pointer<Int32> size);

typedef CorsairSubscribeForEventsNative = Int32 Function(
    Pointer<NativeFunction<CorsairEventHandlerNative>> onEvent,
    Pointer<Void> context);
typedef CorsairSubscribeForEventsDart = int Function(
    Pointer<NativeFunction<CorsairEventHandlerNative>> onEvent,
    Pointer<Void> context);

typedef CorsairUnsubscribeFromEventsNative = Int32 Function();
typedef CorsairUnsubscribeFromEventsDart = int Function();

typedef CorsairConfigureKeyEventNative = Int32 Function(
    Pointer<Utf8> deviceId, Pointer<CorsairKeyEventConfiguration> config);
typedef CorsairConfigureKeyEventDart = int Function(
    Pointer<Utf8> deviceId, Pointer<CorsairKeyEventConfiguration> config);

typedef CorsairGetDevicePropertyInfoNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 propertyId,
    Uint32 index,
    Pointer<Int32> dataType,
    Pointer<Uint32> flags);
typedef CorsairGetDevicePropertyInfoDart = int Function(
    Pointer<Utf8> deviceId,
    int propertyId,
    int index,
    Pointer<Int32> dataType,
    Pointer<Uint32> flags);

typedef CorsairReadDevicePropertyNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 propertyId,
    Uint32 index,
    Pointer<CorsairProperty> property);
typedef CorsairReadDevicePropertyDart = int Function(
    Pointer<Utf8> deviceId,
    int propertyId,
    int index,
    Pointer<CorsairProperty> property);

typedef CorsairWriteDevicePropertyNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 propertyId,
    Uint32 index,
    Pointer<CorsairProperty> property);
typedef CorsairWriteDevicePropertyDart = int Function(
    Pointer<Utf8> deviceId,
    int propertyId,
    int index,
    Pointer<CorsairProperty> property);

typedef CorsairFreePropertyNative = Int32 Function(
    Pointer<CorsairProperty> property);
typedef CorsairFreePropertyDart = int Function(
    Pointer<CorsairProperty> property);

typedef CorsairSetLedColorsNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 size,
    Pointer<CorsairLedColor> ledColors);
typedef CorsairSetLedColorsDart = int Function(
    Pointer<Utf8> deviceId,
    int size,
    Pointer<CorsairLedColor> ledColors);

typedef CorsairSetLedColorsBufferNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 size,
    Pointer<CorsairLedColor> ledColors);
typedef CorsairSetLedColorsBufferDart = int Function(
    Pointer<Utf8> deviceId,
    int size,
    Pointer<CorsairLedColor> ledColors);

typedef CorsairSetLedColorsFlushBufferAsyncNative = Int32 Function(
    Pointer<NativeFunction<CorsairAsyncCallbackNative>> callback,
    Pointer<Void> context);
typedef CorsairSetLedColorsFlushBufferAsyncDart = int Function(
    Pointer<NativeFunction<CorsairAsyncCallbackNative>> callback,
    Pointer<Void> context);

typedef CorsairGetLedColorsNative = Int32 Function(
    Pointer<Utf8> deviceId,
    Int32 size,
    Pointer<CorsairLedColor> ledColors);
typedef CorsairGetLedColorsDart = int Function(
    Pointer<Utf8> deviceId,
    int size,
    Pointer<CorsairLedColor> ledColors);

typedef CorsairSetLayerPriorityNative = Int32 Function(Uint32 priority);
typedef CorsairSetLayerPriorityDart = int Function(int priority);

typedef CorsairGetLedLuidForKeyNameNative = Int32 Function(
    Pointer<Utf8> deviceId, Int8 keyName, Pointer<Uint32> ledId);
typedef CorsairGetLedLuidForKeyNameDart = int Function(
    Pointer<Utf8> deviceId, int keyName, Pointer<Uint32> ledId);

typedef CorsairRequestControlNative = Int32 Function(
    Pointer<Utf8> deviceId, Int32 accessLevel);
typedef CorsairRequestControlDart = int Function(
    Pointer<Utf8> deviceId, int accessLevel);

typedef CorsairReleaseControlNative = Int32 Function(Pointer<Utf8> deviceId);
typedef CorsairReleaseControlDart = int Function(Pointer<Utf8> deviceId);

/// Wrapper class for loading iCUE DLL and resolving native bindings.
class IcueBindings {
  late final DynamicLibrary _dylib;

  late final CorsairConnectDart corsairConnect;
  late final CorsairDisconnectDart corsairDisconnect;
  late final CorsairGetSessionDetailsDart corsairGetSessionDetails;
  late final CorsairGetDevicesDart corsairGetDevices;
  late final CorsairGetDeviceInfoDart corsairGetDeviceInfo;
  late final CorsairGetLedPositionsDart corsairGetLedPositions;
  late final CorsairSubscribeForEventsDart corsairSubscribeForEvents;
  late final CorsairUnsubscribeFromEventsDart corsairUnsubscribeFromEvents;
  late final CorsairConfigureKeyEventDart corsairConfigureKeyEvent;
  late final CorsairGetDevicePropertyInfoDart corsairGetDevicePropertyInfo;
  late final CorsairReadDevicePropertyDart corsairReadDeviceProperty;
  late final CorsairWriteDevicePropertyDart corsairWriteDeviceProperty;
  late final CorsairFreePropertyDart corsairFreeProperty;
  late final CorsairSetLedColorsDart corsairSetLedColors;
  late final CorsairSetLedColorsBufferDart corsairSetLedColorsBuffer;
  late final CorsairSetLedColorsFlushBufferAsyncDart corsairSetLedColorsFlushBufferAsync;
  late final CorsairGetLedColorsDart corsairGetLedColors;
  late final CorsairSetLayerPriorityDart corsairSetLayerPriority;
  late final CorsairGetLedLuidForKeyNameDart corsairGetLedLuidForKeyName;
  late final CorsairRequestControlDart corsairRequestControl;
  late final CorsairReleaseControlDart corsairReleaseControl;

  IcueBindings({String? dllPath}) {
    _dylib = _openDynamicLibrary(dllPath);

    corsairConnect = _dylib
        .lookup<NativeFunction<CorsairConnectNative>>('CorsairConnect')
        .asFunction();

    corsairDisconnect = _dylib
        .lookup<NativeFunction<CorsairDisconnectNative>>('CorsairDisconnect')
        .asFunction();

    corsairGetSessionDetails = _dylib
        .lookup<NativeFunction<CorsairGetSessionDetailsNative>>(
            'CorsairGetSessionDetails')
        .asFunction();

    corsairGetDevices = _dylib
        .lookup<NativeFunction<CorsairGetDevicesNative>>('CorsairGetDevices')
        .asFunction();

    corsairGetDeviceInfo = _dylib
        .lookup<NativeFunction<CorsairGetDeviceInfoNative>>('CorsairGetDeviceInfo')
        .asFunction();

    corsairGetLedPositions = _dylib
        .lookup<NativeFunction<CorsairGetLedPositionsNative>>(
            'CorsairGetLedPositions')
        .asFunction();

    corsairSubscribeForEvents = _dylib
        .lookup<NativeFunction<CorsairSubscribeForEventsNative>>(
            'CorsairSubscribeForEvents')
        .asFunction();

    corsairUnsubscribeFromEvents = _dylib
        .lookup<NativeFunction<CorsairUnsubscribeFromEventsNative>>(
            'CorsairUnsubscribeFromEvents')
        .asFunction();

    corsairConfigureKeyEvent = _dylib
        .lookup<NativeFunction<CorsairConfigureKeyEventNative>>(
            'CorsairConfigureKeyEvent')
        .asFunction();

    corsairGetDevicePropertyInfo = _dylib
        .lookup<NativeFunction<CorsairGetDevicePropertyInfoNative>>(
            'CorsairGetDevicePropertyInfo')
        .asFunction();

    corsairReadDeviceProperty = _dylib
        .lookup<NativeFunction<CorsairReadDevicePropertyNative>>(
            'CorsairReadDeviceProperty')
        .asFunction();

    corsairWriteDeviceProperty = _dylib
        .lookup<NativeFunction<CorsairWriteDevicePropertyNative>>(
            'CorsairWriteDeviceProperty')
        .asFunction();

    corsairFreeProperty = _dylib
        .lookup<NativeFunction<CorsairFreePropertyNative>>('CorsairFreeProperty')
        .asFunction();

    corsairSetLedColors = _dylib
        .lookup<NativeFunction<CorsairSetLedColorsNative>>('CorsairSetLedColors')
        .asFunction();

    corsairSetLedColorsBuffer = _dylib
        .lookup<NativeFunction<CorsairSetLedColorsBufferNative>>(
            'CorsairSetLedColorsBuffer')
        .asFunction();

    corsairSetLedColorsFlushBufferAsync = _dylib
        .lookup<NativeFunction<CorsairSetLedColorsFlushBufferAsyncNative>>(
            'CorsairSetLedColorsFlushBufferAsync')
        .asFunction();

    corsairGetLedColors = _dylib
        .lookup<NativeFunction<CorsairGetLedColorsNative>>('CorsairGetLedColors')
        .asFunction();

    corsairSetLayerPriority = _dylib
        .lookup<NativeFunction<CorsairSetLayerPriorityNative>>(
            'CorsairSetLayerPriority')
        .asFunction();

    corsairGetLedLuidForKeyName = _dylib
        .lookup<NativeFunction<CorsairGetLedLuidForKeyNameNative>>(
            'CorsairGetLedLuidForKeyName')
        .asFunction();

    corsairRequestControl = _dylib
        .lookup<NativeFunction<CorsairRequestControlNative>>(
            'CorsairRequestControl')
        .asFunction();

    corsairReleaseControl = _dylib
        .lookup<NativeFunction<CorsairReleaseControlNative>>(
            'CorsairReleaseControl')
        .asFunction();
  }

  DynamicLibrary _openDynamicLibrary(String? customPath) {
    if (customPath != null) {
      return DynamicLibrary.open(customPath);
    }

    if (Platform.isWindows) {
      final localDll = File('assets/libs/iCUESDK.x64_2019.dll');
      if (localDll.existsSync()) {
        return DynamicLibrary.open(localDll.absolute.path);
      }
      try {
        return DynamicLibrary.open('iCUESDK.x64_2019.dll');
      } catch (_) {
        return DynamicLibrary.open('iCUESDK.dll');
      }
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('iCUESDK.dylib');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libiCUESDK.so');
    }
    throw UnsupportedError('Platform not supported for iCUE SDK: ${Platform.operatingSystem}');
  }
}
