import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'icue_service.dart';

class IcueDashboardScreen extends StatefulWidget {
  const IcueDashboardScreen({super.key});

  @override
  State<IcueDashboardScreen> createState() => _IcueDashboardScreenState();
}

class _IcueDashboardScreenState extends State<IcueDashboardScreen> {
  late final IcueService _icueService;
  StreamSubscription<CorsairSessionState>? _sessionStateSubscription;

  IcueSessionDetails? _sessionDetails;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _icueService = IcueService();

    // Escuta reativamente as mudanças no estado da sessão iCUE
    _sessionStateSubscription = _icueService.onSessionStateChanged.listen((
      sessionState,
    ) {
      _fetchSessionInfo();
      if (mounted) {
        setState(() {});
      }
    });

    _fetchSessionInfo();
  }

  @override
  void dispose() {
    _sessionStateSubscription?.cancel();
    _icueService.dispose();
    super.dispose();
  }

  void _fetchSessionInfo() {
    final result = _icueService.getSessionDetails();
    result.fold(
      (details) {
        if (mounted) {
          setState(() {
            _sessionDetails = details;
            _lastError = null;
          });
        }
      },
      (error) {
        if (kDebugMode) {
          print('Erro ao obter detalhes da sessão: $error');
        }
        if (mounted) {
          setState(() {
            _sessionDetails = null;
            _lastError = error.toString();
          });
        }
      },
    );
  }

  void _toggleConnection() {
    final result = !_icueService.isConnected
        ? _icueService.connect()
        : _icueService.disconnect();

    result.fold(
      (_) {
        if (mounted) {
          setState(() {
            _lastError = null;
          });
        }
      },
      (error) {
        print('Erro na conexão/desconexão do iCUE: $error');
        if (mounted) {
          setState(() {
            _lastError = error.toString();
          });
        }
      },
    );

    _fetchSessionInfo();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _icueService.isConnected;
    final isDllLoaded = _icueService.isDllLoaded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('iCUE SDK Integration Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Card de Status da DLL Nativa
            Card(
              elevation: 2,
              color: isDllLoaded ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      isDllLoaded ? Icons.check_circle : Icons.error,
                      color: isDllLoaded ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDllLoaded
                                ? 'iCUE Native DLL Loaded Successfully'
                                : 'iCUE Native DLL Load Failed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDllLoaded
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDllLoaded
                                ? 'Library: iCUESDK.x64_2019.dll'
                                : 'Error: ${_icueService.dllLoadError ?? "Unknown error"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDllLoaded
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

            // Card Informativo e Reativo da Sessão iCUE
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Informações da Sessão',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(
                            isConnected ? Icons.power_settings_new : Icons.link,
                          ),
                          label: Text(
                            !isConnected ? "Conectar" : "Desconectar",
                          ),
                          onPressed: isDllLoaded ? _toggleConnection : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isConnected
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            foregroundColor: isConnected
                                ? Colors.red.shade900
                                : Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Chip(
                          avatar: Icon(
                            isConnected ? Icons.check_circle : Icons.cancel,
                            size: 16,
                            color: isConnected ? Colors.green : Colors.grey,
                          ),
                          label: Text(
                            isConnected ? 'Conectado' : 'Desconectado',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isConnected
                                  ? Colors.green.shade900
                                  : Colors.grey.shade800,
                            ),
                          ),
                          backgroundColor: isConnected
                              ? Colors.green.shade50
                              : Colors.grey.shade200,
                        ),
                      ],
                    ),

                    if (_lastError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Último erro: $_lastError',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: isConnected
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isConnected
                              ? Colors.blue.shade200
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estado da Sessão: ${_icueService.sessionState.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Conectado: ${isConnected ? "Sim" : "Não"}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (_sessionDetails != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Versão Client SDK: ${_sessionDetails!.clientVersion}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Versão Server SDK: ${_sessionDetails!.serverVersion}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Versão iCUE (Host): ${_sessionDetails!.serverHostVersion}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
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
