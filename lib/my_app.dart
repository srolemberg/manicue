import 'package:flutter/material.dart';

import 'icue/icue_dashboard_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'manicue - iCUE Integration',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: const IcueDashboardScreen(),
    );
  }
}
