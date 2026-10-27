import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../core/result.dart';
import 'icue_bindings.dart';
export 'icue_bindings.dart';

/// Manages the iCUE SDK connection, synchronous operations, and event streams.
///
/// The native SDK library is loaded when the service is created. Call
/// [connect] before SDK operations that require an active session, subscribe
/// with [subscribeForEvents] to receive device and key events, and call
/// [dispose] when the service is no longer needed. State, event, and function
/// contracts follow Corsair's [iCUESDK.h](https://github.com/CorsairOfficial/cue-sdk/blob/v4.0.84/src/include/iCUESDK.h)
/// and the project reference in `docs/iocue-sdk.md`. A working session also
/// requires iCUE to be running with third-party control enabled, and both
/// processes should run with matching access rights.
class IcueService {
  late final IcueBindings _bindings;
  bool _isConnected = false;
  bool _isDllLoaded = false;
  String? _dllLoadError;
  CorsairSessionState _sessionState = CorsairSessionState.cssClosed;

  late final NativeCallable<CorsairSessionStateChangedNative> _stateCallable;
  NativeCallable<CorsairEventHandlerNative>? _eventCallable;

  final _stateController = StreamController<CorsairSessionState>.broadcast();
  final _eventController = StreamController<IcueEvent>.broadcast();
  final _deviceConnectionController =
      StreamController<IcueDeviceConnectionStatusChangedEvent>.broadcast();
  final _keyEventController = StreamController<IcueKeyEvent>.broadcast();

  /// Emits session-state changes reported by the native SDK callback.
  Stream<CorsairSessionState> get onSessionStateChanged =>
      _stateController.stream;

  /// Emits each supported event received from the native SDK subscription.
  Stream<IcueEvent> get onEvent => _eventController.stream;

  /// Emits device connection and disconnection events.
  Stream<IcueDeviceConnectionStatusChangedEvent>
  get onDeviceConnectionStatusChanged => _deviceConnectionController.stream;

  /// Emits programmable key press and release events.
  Stream<IcueKeyEvent> get onKeyEvent => _keyEventController.stream;

  /// Creates a service and attempts to load the SDK library.
  ///
  /// If [dllPath] is provided, it is used as the library path. A loading
  /// failure is exposed through [isDllLoaded] and [dllLoadError].
  IcueService({String? dllPath}) {
    try {
      _bindings = IcueBindings(dllPath: dllPath);
      _isDllLoaded = true;

      // Setup native session state callback listener
      _stateCallable =
          NativeCallable<CorsairSessionStateChangedNative>.listener(
            _onStateChangedNative,
          );
    } catch (e) {
      _isDllLoaded = false;
      _dllLoadError = e.toString();
    }
  }

  /// Whether the SDK reports an active session connection.
  bool get isConnected => _isConnected;

  /// Whether the native SDK library and required symbols were loaded.
  bool get isDllLoaded => _isDllLoaded;

  /// Error captured while loading the native library, if loading failed.
  String? get dllLoadError => _dllLoadError;

  /// Most recently observed native session state.
  CorsairSessionState get sessionState => _sessionState;

  void _onStateChangedNative(
    Pointer<Void> context,
    Pointer<CorsairSessionStateChanged> eventData,
  ) {
    if (eventData != nullptr) {
      final stateInt = eventData.ref.state;
      _sessionState = CorsairSessionState.fromValue(stateInt);
      _isConnected = (_sessionState == CorsairSessionState.cssConnected);
      _stateController.add(_sessionState);
    }
  }

  void _onEventNative(Pointer<Void> context, Pointer<CorsairEvent> eventPtr) {
    if (eventPtr == nullptr) return;
    final eventId = CorsairEventId.fromValue(eventPtr.ref.id);
    final unionPtr = eventPtr.ref.eventDataUnion;

    if (eventId == CorsairEventId.ceiDeviceConnectionStatusChangedEvent &&
        unionPtr != nullptr) {
      final statusEvt = unionPtr
          .cast<CorsairDeviceConnectionStatusChangedEvent>()
          .ref;
      final eventObj = IcueDeviceConnectionStatusChangedEvent(
        deviceId: statusEvt.deviceIdString,
        isConnected: statusEvt.isConnected,
      );
      _eventController.add(eventObj);
      _deviceConnectionController.add(eventObj);
    } else if (eventId == CorsairEventId.ceiKeyEvent && unionPtr != nullptr) {
      final keyEvt = unionPtr.cast<CorsairKeyEvent>().ref;
      final eventObj = IcueKeyEvent(
        deviceId: keyEvt.deviceIdString,
        keyId: CorsairMacroKeyId.fromValue(keyEvt.keyId),
        isPressed: keyEvt.isPressed,
      );
      _eventController.add(eventObj);
      _keyEventController.add(eventObj);
    }
  }

  /// Returns a readable description for an SDK [error] code.
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

  /// Opens a client session with iCUE and starts receiving state changes.
  ///
  /// Returns [Success] when the connection request succeeds, or [Failure]
  /// with an [IcueException] when the library or SDK rejects it.
  Result<void, IcueException> connect() {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'Cannot connect: iCUE DLL failed to load: $_dllLoadError',
        ),
      );
    }

    try {
      int errorCode = _bindings.corsairConnect(
        _stateCallable.nativeFunction,
        nullptr,
      );
      var error = CorsairError.fromValue(errorCode);

      // Self-healing: if CE_InvalidOperation occurs (orphaned session / already connected),
      // force a cleanup disconnect and retry connection once.
      if (error == CorsairError.ceInvalidOperation) {
        _bindings.corsairDisconnect();
        errorCode = _bindings.corsairConnect(
          _stateCallable.nativeFunction,
          nullptr,
        );
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
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairConnect: $e',
        ),
      );
    }
  }

  /// Closes the current client session with iCUE.
  ///
  /// Disconnecting an already closed session is treated as success.
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
      if (error == CorsairError.ceSuccess ||
          error == CorsairError.ceNotConnected) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairDisconnect: $e',
        ),
      );
    }
  }

  /// Reads the SDK client, SDK server, and iCUE host versions.
  Result<IcueSessionDetails, IcueException> getSessionDetails() {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
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
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetSessionDetails: $e',
        ),
      );
    } finally {
      calloc.free(detailsPtr);
    }
  }

  /// Lists currently connected devices, optionally filtered by [filterType].
  Result<List<IcueDevice>, IcueException> getDevices({
    CorsairDeviceType filterType = CorsairDeviceType.cdtAll,
  }) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final filterPtr = calloc<CorsairDeviceFilter>()
      ..ref.deviceTypeMask = filterType.value;
    final sizePtr = calloc<Int32>();
    final maxDevices = corsairDeviceCountMax;
    final devicesPtr = calloc<CorsairDeviceInfo>(maxDevices);

    try {
      sizePtr.value = maxDevices;
      final errorCode = _bindings.corsairGetDevices(
        filterPtr,
        maxDevices,
        devicesPtr,
        sizePtr,
      );
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
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetDevices: $e',
        ),
      );
    } finally {
      calloc.free(filterPtr);
      calloc.free(sizePtr);
      calloc.free(devicesPtr);
    }
  }

  /// Reads the current information for the device identified by [deviceId].
  Result<IcueDevice, IcueException> getDeviceInfo(String deviceId) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final deviceInfoPtr = calloc<CorsairDeviceInfo>();

    try {
      final errorCode = _bindings.corsairGetDeviceInfo(
        deviceIdPtr,
        deviceInfoPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return Success(IcueDevice.fromNative(deviceInfoPtr.ref));
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetDeviceInfo: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(deviceInfoPtr);
    }
  }

  /// Reads up to [maxLeds] LED identifiers and layout positions for [deviceId].
  Result<List<IcueLedPosition>, IcueException> getLedPositions(
    String deviceId, {
    int maxLeds = corsairDeviceLedCountMax,
  }) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final ledPositionsPtr = calloc<CorsairLedPosition>(maxLeds);
    final sizePtr = calloc<Int32>()..value = maxLeds;

    try {
      final errorCode = _bindings.corsairGetLedPositions(
        deviceIdPtr,
        maxLeds,
        ledPositionsPtr,
        sizePtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        final count = sizePtr.value;
        final list = <IcueLedPosition>[];
        for (var i = 0; i < count; i++) {
          final pos = (ledPositionsPtr + i).ref;
          list.add(IcueLedPosition.fromNative(pos));
        }
        return Success(list);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetLedPositions: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(ledPositionsPtr);
      calloc.free(sizePtr);
    }
  }

  /// Subscribes to SDK events and forwards supported events to the streams.
  ///
  /// A successful subscription enables [onEvent], [onDeviceConnectionStatusChanged],
  /// and [onKeyEvent]. The service must remain alive until unsubscribed.
  Result<void, IcueException> subscribeForEvents() {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    try {
      _eventCallable?.close();
      _eventCallable = NativeCallable<CorsairEventHandlerNative>.listener(
        _onEventNative,
      );

      final errorCode = _bindings.corsairSubscribeForEvents(
        _eventCallable!.nativeFunction,
        nullptr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairSubscribeForEvents: $e',
        ),
      );
    }
  }

  /// Stops the native event subscription and releases its callback.
  Result<void, IcueException> unsubscribeFromEvents() {
    if (!_isDllLoaded) return const Success(null);

    try {
      final errorCode = _bindings.corsairUnsubscribeFromEvents();
      _eventCallable?.close();
      _eventCallable = null;

      final error = CorsairError.fromValue(errorCode);
      if (error == CorsairError.ceSuccess ||
          error == CorsairError.ceNotConnected) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairUnsubscribeFromEvents: $e',
        ),
      );
    }
  }

  /// Enables or disables interception of [keyId] on [deviceId].
  ///
  /// Key interception may require corresponding permission in iCUE settings.
  Result<void, IcueException> configureKeyEvent(
    String deviceId,
    CorsairMacroKeyId keyId,
    bool isIntercepted,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final configPtr = calloc<CorsairKeyEventConfiguration>();

    try {
      configPtr.ref
        ..keyId = keyId.value
        ..isIntercepted = isIntercepted;

      final errorCode = _bindings.corsairConfigureKeyEvent(
        deviceIdPtr,
        configPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairConfigureKeyEvent: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(configPtr);
    }
  }

  /// Reads the type and access flags for a device [propertyId].
  ///
  /// Use [index] for properties marked as indexed by the SDK.
  Result<IcueDevicePropertyInfo, IcueException> getDevicePropertyInfo(
    String deviceId,
    CorsairDevicePropertyId propertyId, {
    int index = 0,
  }) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final dataTypePtr = calloc<Int32>();
    final flagsPtr = calloc<Uint32>();

    try {
      final errorCode = _bindings.corsairGetDevicePropertyInfo(
        deviceIdPtr,
        propertyId.value,
        index,
        dataTypePtr,
        flagsPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        final info = IcueDevicePropertyInfo(
          dataType: CorsairDataType.fromValue(dataTypePtr.value),
          flags: flagsPtr.value,
        );
        return Success(info);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetDevicePropertyInfo: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(dataTypePtr);
      calloc.free(flagsPtr);
    }
  }

  /// Reads a device property and copies its native value into Dart-managed data.
  ///
  /// Use [index] for indexed properties. The returned [IcueProperty] contains
  /// a Dart value matching the property's [CorsairDataType].
  Result<IcueProperty, IcueException> readDeviceProperty(
    String deviceId,
    CorsairDevicePropertyId propertyId, {
    int index = 0,
  }) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final propertyPtr = calloc<CorsairProperty>();

    try {
      final errorCode = _bindings.corsairReadDeviceProperty(
        deviceIdPtr,
        propertyId.value,
        index,
        propertyPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        final dataType = CorsairDataType.fromValue(propertyPtr.ref.type);
        dynamic value;

        switch (dataType) {
          case CorsairDataType.ctBoolean:
            value = propertyPtr.ref.value.boolean;
            break;
          case CorsairDataType.ctInt32:
            value = propertyPtr.ref.value.int32;
            break;
          case CorsairDataType.ctFloat64:
            value = propertyPtr.ref.value.float64;
            break;
          case CorsairDataType.ctString:
            final strPtr = propertyPtr.ref.value.string;
            value = (strPtr != nullptr) ? strPtr.toDartString() : '';
            break;
          case CorsairDataType.ctBooleanArray:
            final arr = propertyPtr.ref.value.booleanArray;
            final bools = <bool>[];
            if (arr.items != nullptr) {
              for (var i = 0; i < arr.count; i++) {
                bools.add(arr.items[i]);
              }
            }
            value = bools;
            break;
          case CorsairDataType.ctInt32Array:
            final arr = propertyPtr.ref.value.intArray;
            final ints = <int>[];
            if (arr.items != nullptr) {
              for (var i = 0; i < arr.count; i++) {
                ints.add(arr.items[i]);
              }
            }
            value = ints;
            break;
          case CorsairDataType.ctFloat64Array:
            final arr = propertyPtr.ref.value.floatArray;
            final floats = <double>[];
            if (arr.items != nullptr) {
              for (var i = 0; i < arr.count; i++) {
                floats.add(arr.items[i]);
              }
            }
            value = floats;
            break;
          case CorsairDataType.ctStringArray:
            final arr = propertyPtr.ref.value.stringArray;
            final strings = <String>[];
            if (arr.items != nullptr) {
              for (var i = 0; i < arr.count; i++) {
                final itemPtr = arr.items[i];
                if (itemPtr != nullptr) {
                  strings.add(itemPtr.toDartString());
                }
              }
            }
            value = strings;
            break;
        }

        // Free native property memory allocated by iCUE SDK
        _bindings.corsairFreeProperty(propertyPtr);

        return Success(IcueProperty(type: dataType, value: value));
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairReadDeviceProperty: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(propertyPtr);
    }
  }

  /// Writes [property] to a device property identified by [propertyId].
  ///
  /// The value in [property] must match its declared data type. Use [index]
  /// for indexed properties.
  Result<void, IcueException> writeDeviceProperty(
    String deviceId,
    CorsairDevicePropertyId propertyId,
    IcueProperty property, {
    int index = 0,
  }) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final propertyPtr = calloc<CorsairProperty>();
    final pointersToFree = <Pointer>[];

    try {
      propertyPtr.ref.type = property.type.value;

      switch (property.type) {
        case CorsairDataType.ctBoolean:
          propertyPtr.ref.value.boolean = property.value as bool;
          break;
        case CorsairDataType.ctInt32:
          propertyPtr.ref.value.int32 = property.value as int;
          break;
        case CorsairDataType.ctFloat64:
          propertyPtr.ref.value.float64 = (property.value as num).toDouble();
          break;
        case CorsairDataType.ctString:
          final strPtr = (property.value as String).toNativeUtf8();
          pointersToFree.add(strPtr);
          propertyPtr.ref.value.string = strPtr;
          break;
        case CorsairDataType.ctBooleanArray:
          final list = property.value as List<bool>;
          final itemsPtr = calloc<Bool>(list.length);
          pointersToFree.add(itemsPtr);
          for (var i = 0; i < list.length; i++) {
            itemsPtr[i] = list[i];
          }
          propertyPtr.ref.value.booleanArray.items = itemsPtr;
          propertyPtr.ref.value.booleanArray.count = list.length;
          break;
        case CorsairDataType.ctInt32Array:
          final list = property.value as List<int>;
          final itemsPtr = calloc<Int32>(list.length);
          pointersToFree.add(itemsPtr);
          for (var i = 0; i < list.length; i++) {
            itemsPtr[i] = list[i];
          }
          propertyPtr.ref.value.intArray.items = itemsPtr;
          propertyPtr.ref.value.intArray.count = list.length;
          break;
        case CorsairDataType.ctFloat64Array:
          final list = property.value as List<num>;
          final itemsPtr = calloc<Double>(list.length);
          pointersToFree.add(itemsPtr);
          for (var i = 0; i < list.length; i++) {
            itemsPtr[i] = list[i].toDouble();
          }
          propertyPtr.ref.value.floatArray.items = itemsPtr;
          propertyPtr.ref.value.floatArray.count = list.length;
          break;
        case CorsairDataType.ctStringArray:
          final list = property.value as List<String>;
          final itemsPtr = calloc<Pointer<Utf8>>(list.length);
          pointersToFree.add(itemsPtr);
          for (var i = 0; i < list.length; i++) {
            final strPtr = list[i].toNativeUtf8();
            pointersToFree.add(strPtr);
            itemsPtr[i] = strPtr;
          }
          propertyPtr.ref.value.stringArray.items = itemsPtr;
          propertyPtr.ref.value.stringArray.count = list.length;
          break;
      }

      final errorCode = _bindings.corsairWriteDeviceProperty(
        deviceIdPtr,
        propertyId.value,
        index,
        propertyPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairWriteDeviceProperty: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(propertyPtr);
      for (final ptr in pointersToFree) {
        calloc.free(ptr);
      }
    }
  }

  /// Releases property memory allocated by the native SDK.
  ///
  /// A null [propertyPtr] is treated as a no-op. Values returned by
  /// [readDeviceProperty] have already been copied and freed internally.
  Result<void, IcueException> freeProperty(
    Pointer<CorsairProperty> propertyPtr,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    if (propertyPtr == nullptr) {
      return const Success(null);
    }

    try {
      final errorCode = _bindings.corsairFreeProperty(propertyPtr);
      final error = CorsairError.fromValue(errorCode);
      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairFreeProperty: $e',
        ),
      );
    }
  }

  /// Sets [colors] on the specified LEDs of [deviceId] immediately.
  ///
  /// LED identifiers should be obtained from the SDK layout/key APIs. An
  /// empty list performs no native call and succeeds.
  Result<void, IcueException> setLedColors(
    String deviceId,
    List<IcueLedColor> colors,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    if (colors.isEmpty) {
      return const Success(null);
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final ledColorsPtr = calloc<CorsairLedColor>(colors.length);

    try {
      for (var i = 0; i < colors.length; i++) {
        final color = colors[i];
        (ledColorsPtr + i).ref
          ..id = color.id
          ..r = color.r
          ..g = color.g
          ..b = color.b
          ..a = color.a;
      }

      final errorCode = _bindings.corsairSetLedColors(
        deviceIdPtr,
        colors.length,
        ledColorsPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairSetLedColors: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(ledColorsPtr);
    }
  }

  /// Convenience wrapper for setting a single LED color
  Result<void, IcueException> setLedColor(
    String deviceId,
    int ledId,
    int r,
    int g,
    int b, [
    int a = 255,
  ]) {
    return setLedColors(deviceId, [
      IcueLedColor(id: ledId, r: r, g: g, b: b, a: a),
    ]);
  }

  /// Adds [colors] to the SDK's pending LED color buffer for [deviceId].
  ///
  /// Call [setLedColorsFlushBufferAsync] to submit buffered colors to devices.
  Result<void, IcueException> setLedColorsBuffer(
    String deviceId,
    List<IcueLedColor> colors,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    if (colors.isEmpty) {
      return const Success(null);
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final ledColorsPtr = calloc<CorsairLedColor>(colors.length);

    try {
      for (var i = 0; i < colors.length; i++) {
        final color = colors[i];
        (ledColorsPtr + i).ref
          ..id = color.id
          ..r = color.r
          ..g = color.g
          ..b = color.b
          ..a = color.a;
      }

      final errorCode = _bindings.corsairSetLedColorsBuffer(
        deviceIdPtr,
        colors.length,
        ledColorsPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairSetLedColorsBuffer: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(ledColorsPtr);
    }
  }

  /// Asynchronously sends colors previously staged with [setLedColorsBuffer].
  ///
  /// If supplied, [callback] receives the SDK completion status.
  Result<void, IcueException> setLedColorsFlushBufferAsync([
    void Function(CorsairError error)? callback,
  ]) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    try {
      NativeCallable<CorsairAsyncCallbackNative>? callable;
      Pointer<NativeFunction<CorsairAsyncCallbackNative>> cbFunc = nullptr;

      if (callback != null) {
        callable = NativeCallable<CorsairAsyncCallbackNative>.listener((
          Pointer<Void> context,
          int errorInt,
        ) {
          final error = CorsairError.fromValue(errorInt);
          callback(error);
          callable?.close();
        });
        cbFunc = callable.nativeFunction;
      }

      final errorCode = _bindings.corsairSetLedColorsFlushBufferAsync(
        cbFunc,
        nullptr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        callable?.close();
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairSetLedColorsFlushBufferAsync: $e',
        ),
      );
    }
  }

  /// Reads the current colors for [ledIds] on [deviceId].
  Result<List<IcueLedColor>, IcueException> getLedColors(
    String deviceId,
    List<int> ledIds,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    if (ledIds.isEmpty) {
      return const Success([]);
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final ledColorsPtr = calloc<CorsairLedColor>(ledIds.length);

    try {
      for (var i = 0; i < ledIds.length; i++) {
        (ledColorsPtr + i).ref.id = ledIds[i];
      }

      final errorCode = _bindings.corsairGetLedColors(
        deviceIdPtr,
        ledIds.length,
        ledColorsPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        final resultList = <IcueLedColor>[];
        for (var i = 0; i < ledIds.length; i++) {
          resultList.add(IcueLedColor.fromNative((ledColorsPtr + i).ref));
        }
        return Success(resultList);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetLedColors: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(ledColorsPtr);
    }
  }

  /// Sets the priority of the current lighting layer.
  ///
  /// [priority] must be within the SDK range from 0 to
  /// [corsairLayerPriorityMax].
  Result<void, IcueException> setLayerPriority(int priority) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    try {
      final errorCode = _bindings.corsairSetLayerPriority(priority);
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairSetLayerPriority: $e',
        ),
      );
    }
  }

  /// Resolves a keyboard key name to its device-specific LED identifier.
  ///
  /// The returned identifier is an SDK LED LUID suitable for LED operations.
  Result<int, IcueException> getLedLuidForKeyName(
    String deviceId,
    String keyName,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();
    final ledIdPtr = calloc<Uint32>();
    final keyByte = keyName.isNotEmpty ? keyName.codeUnits.first : 0;

    try {
      final errorCode = _bindings.corsairGetLedLuidForKeyName(
        deviceIdPtr,
        keyByte,
        ledIdPtr,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return Success(ledIdPtr.value);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairGetLedLuidForKeyName: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
      calloc.free(ledIdPtr);
    }
  }

  /// Requests the specified [accessLevel] for [deviceId].
  ///
  /// Exclusive access may be refused if another client currently owns control.
  Result<void, IcueException> requestControl(
    String deviceId,
    CorsairAccessLevel accessLevel,
  ) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();

    try {
      final errorCode = _bindings.corsairRequestControl(
        deviceIdPtr,
        accessLevel.value,
      );
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairRequestControl: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
    }
  }

  /// Releases the control previously requested for [deviceId].
  Result<void, IcueException> releaseControl(String deviceId) {
    if (!_isDllLoaded) {
      return Failure(
        IcueException(
          CorsairError.ceNotConnected,
          'DLL not loaded: $_dllLoadError',
        ),
      );
    }

    final deviceIdPtr = deviceId.toNativeUtf8();

    try {
      final errorCode = _bindings.corsairReleaseControl(deviceIdPtr);
      final error = CorsairError.fromValue(errorCode);

      if (error == CorsairError.ceSuccess) {
        return const Success(null);
      } else {
        return Failure(IcueException(error, mapErrorDescription(error)));
      }
    } catch (e) {
      return Failure(
        IcueException(
          CorsairError.ceInvalidOperation,
          'Exception during CorsairReleaseControl: $e',
        ),
      );
    } finally {
      calloc.free(deviceIdPtr);
    }
  }

  /// Closes event streams, releases native callbacks, and disconnects the SDK.
  void dispose() {
    _stateController.close();
    _eventController.close();
    _deviceConnectionController.close();
    _keyEventController.close();
    if (_isDllLoaded) {
      if (_eventCallable != null) {
        unsubscribeFromEvents();
      }
      if (_isConnected) {
        disconnect();
      }
      _stateCallable.close();
    }
  }
}
