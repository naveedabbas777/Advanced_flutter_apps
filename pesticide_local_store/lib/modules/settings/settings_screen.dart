import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: SwitchListTile(
                  title: const Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: false,
                  onChanged: (val) {},
                  secondary: const Icon(
                    Icons.brightness_6,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.backup, color: Colors.deepPurple),
                  title: const Text(
                    'Backup Data',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.restore, color: Colors.deepPurple),
                  title: const Text(
                    'Restore Data',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info, color: Colors.deepPurple),
                  title: const Text(
                    'App Info',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Version 1.0.0'),
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
