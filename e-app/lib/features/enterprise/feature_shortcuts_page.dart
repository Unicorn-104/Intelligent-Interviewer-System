import 'package:flutter/material.dart';

/// Navigation and private entry models stay in the shell.
class FeatureShortcutsPage extends StatelessWidget {
  const FeatureShortcutsPage({super.key, required this.sections});
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('更多功能')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: sections,
    ),
  );
}
