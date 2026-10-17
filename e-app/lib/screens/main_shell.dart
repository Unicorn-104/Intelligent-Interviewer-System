import 'package:flutter/material.dart';

import '../features/auth/auth_controller.dart';
import '../features/enterprise/enterprise_repository.dart';
import 'dashboard_screen.dart';
import 'jobs_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'talent_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.auth, required this.repository});
  final AuthController auth;
  final EnterpriseRepository repository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(repository: widget.repository, displayName: widget.auth.displayName, onOpenJobs: () => setState(() => _index = 1)),
      JobsScreen(repository: widget.repository),
      TalentScreen(repository: widget.repository),
      MessagesScreen(repository: widget.repository),
      ProfileScreen(repository: widget.repository, auth: widget.auth),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '工作台'),
          NavigationDestination(icon: Icon(Icons.work_outline), selectedIcon: Icon(Icons.work), label: '岗位'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: '人才'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '消息'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}
