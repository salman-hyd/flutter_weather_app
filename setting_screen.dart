import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final Function(String) onUnitChanged;

  const SettingsScreen({required this.onUnitChanged});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _unit = 'metric';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListTile(
        title: const Text('Temperature Unit'),
        trailing: DropdownButton<String>(
          value: _unit,
          items: ['metric', 'imperial'].map((unit) => DropdownMenuItem(value: unit, child: Text(unit == 'metric' ? 'Celsius' : 'Fahrenheit'))).toList(),
          onChanged: (value) {
            setState(() => _unit = value!);
            widget.onUnitChanged(_unit);
          },
        ),
      ),
    );
  }
}