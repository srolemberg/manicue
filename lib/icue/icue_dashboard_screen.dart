import 'package:flutter/material.dart';

import 'icue_service.dart';

class IcueDashboardScreen extends StatefulWidget {
  const IcueDashboardScreen({super.key});

  @override
  State<IcueDashboardScreen> createState() => _IcueDashboardScreenState();
}

class _IcueDashboardScreenState extends State<IcueDashboardScreen> {
  late final IcueService _icueService;
  String _getDevicesText = '';
  String _getConnectionText = '';
  String _getDisconnectionText = '';

  @override
  void initState() {
    super.initState();
    _icueService = IcueService();
  }

  @override
  void dispose() {
    _icueService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iCUE SDK Integration Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // DLL Loading Status Card
            Card(
              elevation: 2,
              color: _icueService.isDllLoaded
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      _icueService.isDllLoaded
                          ? Icons.check_circle
                          : Icons.error,
                      color: _icueService.isDllLoaded
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _icueService.isDllLoaded
                                ? 'iCUE Native DLL Loaded Successfully'
                                : 'iCUE Native DLL Load Failed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _icueService.isDllLoaded
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _icueService.isDllLoaded
                                ? 'Library: iCUESDK.x64_2019.dll'
                                : 'Error: ${_icueService.dllLoadError ?? "Unknown error"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _icueService.isDllLoaded
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Connection test card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Connection Test', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Status: $_getConnectionText'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      child: const Text('Connect iCUE'),
                      onPressed: () {
                        final result = _icueService.connect();
                        result.fold(
                              (_) {
                            setState(() {
                              _getConnectionText = 'Success (Connected)';
                            });
                          },
                              (error) {
                            setState(() {
                              _getConnectionText = error.toString();
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Disconnection test card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disconnection Test', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Status: $_getDisconnectionText'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      child: const Text('Disconnect iCUE'),
                      onPressed: () {
                        final result = _icueService.disconnect();
                        result.fold(
                              (_) {
                            setState(() {
                              _getDisconnectionText = 'Success (Disconnected)';
                            });
                          },
                              (error) {
                            setState(() {
                              _getDisconnectionText = error.toString();
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Connection Test', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Status: $_getConnectionText'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      child: const Text('Connect iCUE'),
                      onPressed: () {
                        final result = _icueService.connect();
                        result.fold(
                              (_) {
                            setState(() {
                              _getConnectionText = 'Success (Connected)';
                            });
                          },
                              (error) {
                            setState(() {
                              _getConnectionText = error.toString();
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
