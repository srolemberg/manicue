import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart';
import '../core/result.dart';
import 'icue_bindings.dart';

class IcueException implements Exception {
  final CorsairError error;
  final String message;

  const IcueException(this.error, this.message);

  @override
  String toString() => 'IcueException: $message (Error: ${error.name}, Code: ${error.value})';
}

class IcueDevice {
  final String id;
  final String serial;
  final String model;
  final CorsairDeviceType type;
  final int ledCount;
  final int channelCount;

  const IcueDevice({
    required this.id,
    required this.serial,
    required this.model,
    required this.type,
    required this.ledCount,
    required this.channelCount,
  });

  factory IcueDevice.fromNative(CorsairDeviceInfo info) {
    return IcueDevice(
      id: info.idString,
      serial: info.serialString,
      model: info.modelString,
      type: CorsairDeviceType.fromValue(info.type),
      ledCount: info.ledCount,
      channelCount: info.channelCount,
    );
  }

  bool get isDisplayDevice =>
      type == CorsairDeviceType.cdtTouchbar || type == CorsairDeviceType.cdtCooler;

  String get typeDisplayName {
    switch (type) {
      case CorsairDeviceType.cdtKeyboard:
        return 'Keyboard';
      case CorsairDeviceType.cdtMouse:
        return 'Mouse';
      case CorsairDeviceType.cdtMousemat:
        return 'Mousemat';
      case CorsairDeviceType.cdtHeadset:
        return 'Headset';
      case CorsairDeviceType.cdtHeadsetStand:
        return 'Headset Stand';
      case CorsairDeviceType.cdtFanLedController:
        return 'Fan LED Controller';
      case CorsairDeviceType.cdtLedController:
        return 'LED Controller';
      case CorsairDeviceType.cdtMemoryModule:
        return 'Memory Module';
      case CorsairDeviceType.cdtCooler:
        return 'Cooler / Display';
      case CorsairDeviceType.cdtMotherboard:
        return 'Motherboard';
      case CorsairDeviceType.cdtGraphicsCard:
        return 'Graphics Card';
      case CorsairDeviceType.cdtTouchbar:
        return 'Touchbar / Display';
      case CorsairDeviceType.cdtGameController:
        return 'Game Controller';
      case CorsairDeviceType.cdtUnknown:
      default:
        return 'Unknown Device';
    }
  }
}

class IcueVersionInfo {
  final int major;
  final int minor;
  final int patch;

  const IcueVersionInfo(this.major, this.minor, this.patch);

  @override
  String toString() => '$major.$minor.$patch';
}

class IcueSessionDetails {
  final IcueVersionInfo clientVersion;
  final IcueVersionInfo serverVersion;
  final IcueVersionInfo serverHostVersion;

  const IcueSessionDetails({
    required this.clientVersion,
    required this.serverVersion,
    required this.serverHostVersion,
  });
}

class IcueService {
  late final IcueBindings _bindings;
  bool _isConnected = false;
  bool _isDllLoaded = false;
  String? _dllLoadError;
  CorsairSessionState _sessionState = CorsairSessionState.cssClosed;

  late final NativeCallable<CorsairSessionStateChangedNative> _stateCallable;
  
  final _stateController = StreamController<CorsairSessionState>.broadcast();
  Stream<CorsairSessionState> get onSessionStateChanged => _stateController.stream;

  IcueService({String? dllPath}) {
    try {
      _bindings = IcueBindings(dllPath: dllPath);
      _isDllLoaded = true;

      // Setup native session state callback listener
      _stateCallable = NativeCallable<CorsairSessionStateChangedNative>.listener(_onStateChangedNative);
    } catch (e) {
      _isDllLoaded = false;
      _dllLoadError = e.toString();
    }
  }

  bool get isConnected => _isConnected;
  bool get isDllLoaded => _isDllLoaded;
  String? get dllLoadError => _dllLoadError;
  CorsairSessionState get sessionState => _sessionState;

  void _onStateChangedNative(Pointer<Void> context, Pointer<CorsairSessionStateChanged> eventData) {
    if (eventData != nullptr) {
      final stateInt = eventData.ref.state;
      _sessionState = CorsairSessionState.fromValue(stateInt);
      _isConnected = (_sessionState == CorsairSessionState.cssConnected);
      _stateController.add(_sessionState);
    }
  }

  String mapErrorDescription(CorsairError error) {
    switch (error) {
      case CorsairError.ceSuccess:
        return 'Success';
      case CorsairError.ceNotConnected:
        return 'Not Connected (iCUE not running, closed, or third-party control disabled in iCUE settings)';
      case CorsairError.ceNoControl:
        return 'No Control (Another client has taken over exclusive control)';
      case CorsairError.ceIncompatibleProtocol:
        return 'Incompatible Protocol (SDK client/server version mismatch)';
      case CorsairError.ceInvalidArguments:
        return 'Invalid Arguments (Supplied arguments are NULL or invalid)';
      case CorsairError.ceInvalidOperation:
        return 'Invalid Operation (CE_InvalidOperation: Called when not allowed due to current state, e.g., calling CorsairConnect while already connected/connecting)';
      case CorsairError.ceDeviceNotFound:
        return 'Device Not Found (Invalid device id or device disconnected)';
      case CorsairError.ceNotAllowed:
        return 'Not Allowed (Key interception or specific functionality disabled in iCUE settings)';
    }
  }

  Result<void, IcueException> connect() {
    if (!_isDllLoaded) {
      return Failure(IcueException(CorsairError.ceNotConnected, 'Cannot connect: iCUE DLL failed to load: $_dllLoadError'));
    }

    try {
      int errorCode = _bindings.corsairConnect(_stateCallable.nativeFunction, nullptr);
      var error = CorsairError.fromValue(errorCode);

      // Self-healing: if CE_InvalidOperation occurs (orphaned session / already connected),
      // force a cleanup disconnect and retry connection once.
      if (error == CorsairError.ceInvalidOperation) {
        _bindings.corsairDisconnect();
        errorCode = _bindings.corsairConnect(_stateCallable.nativeFunction, nullptr);
        error = CorsairError.fromValue(errorCode);
      }

      if (error == CorsairError.ceSuccess) {
        _isConnected = true;
        _sessionState = CorsairSessionState.cssConnected;
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(IcueException(CorsairError.ceInvalidOperation, 'Exception during CorsairConnect: $e'));
    }
  }

  Result<void, IcueException> disconnect() {
    if (!_isDllLoaded) return const Success(null);

    // If already closed / not connected, return success gracefully without throwing CE_NotConnected
    if (!_isConnected && _sessionState == CorsairSessionState.cssClosed) {
      return const Success(null);
    }

    try {
      final errorCode = _bindings.corsairDisconnect();
      _isConnected = false;
      _sessionState = CorsairSessionState.cssClosed;
      
      final error = CorsairError.fromValue(errorCode);
      if (error == CorsairError.ceSuccess || error == CorsairError.ceNotConnected) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(IcueException(CorsairError.ceInvalidOperation, 'Exception during CorsairDisconnect: $e'));
    }
  }

  Result<IcueSessionDetails, IcueException> getSessionDetails() {
    if (!_isDllLoaded) {
      return Failure(IcueException(CorsairError.ceNotConnected, 'DLL not loaded: $_dllLoadError'));
    }

    final detailsPtr = calloc<CorsairSessionDetails>();
    try {
      final errorCode = _bindings.corsairGetSessionDetails(detailsPtr);
      final error = CorsairError.fromValue(errorCode);
      if (error == CorsairError.ceSuccess) {
        final details = detailsPtr.ref;
        final res = IcueSessionDetails(
          clientVersion: IcueVersionInfo(
            details.clientVersion.major,
            details.clientVersion.minor,
            details.clientVersion.patch,
          ),
          serverVersion: IcueVersionInfo(
            details.serverVersion.major,
            details.serverVersion.minor,
            details.serverVersion.patch,
          ),
          serverHostVersion: IcueVersionInfo(
            details.serverHostVersion.major,
            details.serverHostVersion.minor,
            details.serverHostVersion.patch,
          ),
        );
        return Success(res);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(IcueException(CorsairError.ceInvalidOperation, 'Exception during CorsairGetSessionDetails: $e'));
    } finally {
      calloc.free(detailsPtr);
    }
  }

  Result<List<IcueDevice>, IcueException> getDevices({CorsairDeviceType filterType = CorsairDeviceType.cdtAll}) {
    if (!_isDllLoaded) {
      return Failure(IcueException(CorsairError.ceNotConnected, 'DLL not loaded: $_dllLoadError'));
    }

    final filterPtr = calloc<CorsairDeviceFilter>()..ref.deviceTypeMask = filterType.value;
    final sizePtr = calloc<Int32>();
    final maxDevices = corsairDeviceCountMax;
    final devicesPtr = calloc<CorsairDeviceInfo>(maxDevices);

    try {
      sizePtr.value = maxDevices;
      final errorCode = _bindings.corsairGetDevices(filterPtr, maxDevices, devicesPtr, sizePtr);
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        final count = sizePtr.value;
        final list = <IcueDevice>[];
        for (var i = 0; i < count; i++) {
          final deviceInfo = (devicesPtr + i).ref;
          list.add(IcueDevice.fromNative(deviceInfo));
        }
        return Success(list);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(IcueException(CorsairError.ceInvalidOperation, 'Exception during CorsairGetDevices: $e'));
    } finally {
      calloc.free(filterPtr);
      calloc.free(sizePtr);
      calloc.free(devicesPtr);
    }
  }

  Result<void, IcueException> setLedColor(String deviceId, int ledId, int r, int g, int b) {
    if (!_isDllLoaded) {
      return Failure(IcueException(CorsairError.ceNotConnected, 'DLL not loaded: $_dllLoadError'));
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final ledColorPtr = calloc<CorsairLedColor>();

    try {
      ledColorPtr.ref
        ..id = ledId
        ..r = r
        ..g = g
        ..b = b
        ..a = 255;

      final errorCode = _bindings.corsairSetLedColors(deviceIdPtr, 1, ledColorPtr);
      final error = CorsairError.fromValue(errorCode);
      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(IcueException(CorsairError.ceInvalidOperation, 'Exception during CorsairSetLedColors: $e'));
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(ledColorPtr);
    }
  }

  void dispose() {
    _stateController.close();
    if (_isDllLoaded) {
      if (_isConnected) {
        disconnect();
      }
      _stateCallable.close();
    }
  }
}
