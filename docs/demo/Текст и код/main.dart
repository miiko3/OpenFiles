import 'package:flutter/material.dart';

class DemoCard extends StatelessWidget {
  const DemoCard({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: const Text('Пример карточки'),
      ),
    );
  }
}
