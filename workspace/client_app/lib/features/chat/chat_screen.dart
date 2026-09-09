import 'package:flutter/material.dart';

/// Чат с оператором и чат-бот.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поддержка')),
      body: const Center(child: Text('Чат с оператором')),
    );
  }
}
