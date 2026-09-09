import 'package:flutter/material.dart';

/// Профиль клиента: данные, язык интерфейса (ru/en/tr), выход.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.person_outline), title: Text('Данные клиента')),
          ListTile(leading: Icon(Icons.language), title: Text('Язык интерфейса')),
          ListTile(leading: Icon(Icons.hotel_outlined), title: Text('Отель и номер комнаты')),
        ],
      ),
    );
  }
}
