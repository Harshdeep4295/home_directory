import 'package:flutter/material.dart';

void main() {
  runApp(const OfflineHomeApp());
}

/// Placeholder shell; replaced by the real app shell in T5.1.
class OfflineHomeApp extends StatelessWidget {
  const OfflineHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Offline Home',
      home: Scaffold(body: Center(child: Text('Offline Home'))),
    );
  }
}
