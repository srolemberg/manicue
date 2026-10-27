import 'package:flutter_test/flutter_test.dart';
import 'package:manicue/icue/icue_service.dart';

void main() {
  group('IcueService Unit Tests', () {
    late IcueService service;

    setUp(() {
      service = IcueService();
    });

    tearDown(() {
      service.dispose();
    });

    test('IcueService initializes and checks DLL state', () {
      expect(service.sessionState, CorsairSessionState.cssClosed);
      expect(service.isConnected, false);
    });

    test('IcueDevice model conversion', () {
      const device = IcueDevice(
        id: 'dev_123',
        serial: 'SN123456',
        model: 'K95 RGB',
        type: CorsairDeviceType.cdtKeyboard,
        ledCount: 104,
        channelCount: 1,
      );

      expect(device.id, 'dev_123');
      expect(device.typeDisplayName, 'Keyboard');
      expect(device.isDisplayDevice, false);
    });

    test('IcueLedColor model', () {
      const color = IcueLedColor(id: 1, r: 255, g: 128, b: 0);
      expect(color.id, 1);
      expect(color.r, 255);
      expect(color.g, 128);
      expect(color.b, 0);
      expect(color.a, 255);
    });

    test('IcueDevicePropertyInfo model', () {
      const info = IcueDevicePropertyInfo(
        dataType: CorsairDataType.ctInt32,
        flags: CorsairPropertyFlag.cpfCanRead | CorsairPropertyFlag.cpfCanWrite,
      );

      expect(info.canRead, true);
      expect(info.canWrite, true);
      expect(info.isIndexed, false);
    });

    test('IcueService methods return Results safely when not connected or DLL absent', () {
      if (!service.isDllLoaded) {
        final connectRes = service.connect();
        expect(connectRes.isFailure, true);

        final devicesRes = service.getDevices();
        expect(devicesRes.isFailure, true);

        final infoRes = service.getDeviceInfo('invalid');
        expect(infoRes.isFailure, true);

        final ledPosRes = service.getLedPositions('invalid');
        expect(ledPosRes.isFailure, true);

        final subRes = service.subscribeForEvents();
        expect(subRes.isFailure, true);

        final unsubRes = service.unsubscribeFromEvents();
        expect(unsubRes.isSuccess, true);

        final configKeyRes = service.configureKeyEvent(
          'invalid',
          CorsairMacroKeyId.cmki1,
          true,
        );
        expect(configKeyRes.isFailure, true);

        final propInfoRes = service.getDevicePropertyInfo(
          'invalid',
          CorsairDevicePropertyId.cdpiMicEnabled,
        );
        expect(propInfoRes.isFailure, true);

        final readPropRes = service.readDeviceProperty(
          'invalid',
          CorsairDevicePropertyId.cdpiMicEnabled,
        );
        expect(readPropRes.isFailure, true);

        final writePropRes = service.writeDeviceProperty(
          'invalid',
          CorsairDevicePropertyId.cdpiMicEnabled,
          const IcueProperty(type: CorsairDataType.ctBoolean, value: true),
        );
        expect(writePropRes.isFailure, true);

        final setLedColorsRes = service.setLedColors('invalid', [
          const IcueLedColor(id: 1, r: 255, g: 0, b: 0),
        ]);
        expect(setLedColorsRes.isFailure, true);

        final setLedBufferRes = service.setLedColorsBuffer('invalid', [
          const IcueLedColor(id: 1, r: 255, g: 0, b: 0),
        ]);
        expect(setLedBufferRes.isFailure, true);

        final flushRes = service.setLedColorsFlushBufferAsync();
        expect(flushRes.isFailure, true);

        final getLedColorsRes = service.getLedColors('invalid', [1]);
        expect(getLedColorsRes.isFailure, true);

        final layerPrioRes = service.setLayerPriority(100);
        expect(layerPrioRes.isFailure, true);

        final luidRes = service.getLedLuidForKeyName('invalid', 'A');
        expect(luidRes.isFailure, true);

        final reqCtrlRes = service.requestControl(
          'invalid',
          CorsairAccessLevel.calExclusiveLightingControl,
        );
        expect(reqCtrlRes.isFailure, true);

        final relCtrlRes = service.releaseControl('invalid');
        expect(relCtrlRes.isFailure, true);
      }
    });
  });
}
