import 'package:flutter/material.dart';

import '../features/auth/domain/auth_session.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'resume_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.session, required this.onLogout});

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _messageUnreadCount = 0;
  int _messageRefreshVersion = 0;
  int _profileRefreshVersion = 0;

  void _selectTab(int index) => setState(() {
    _index = index;
    if (index == 2) _messageRefreshVersion++;
    if (index == 3) _profileRefreshVersion++;
  });

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        session: widget.session,
        onOpenMessages: () => _selectTab(2),
        unreadCount: _messageUnreadCount,
      ),
      ResumeScreen(session: widget.session),
      MessagesScreen(
        session: widget.session,
        refreshVersion: _messageRefreshVersion,
        onUnreadChanged: (count) {
          if (_messageUnreadCount != count) {
            setState(() => _messageUnreadCount = count);
          }
        },
      ),
      ProfileScreen(
        session: widget.session,
        onLogout: widget.onLogout,
        refreshVersion: _profileRefreshVersion,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          const NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: '简历',
          ),
          NavigationDestination(
            icon: _messageUnreadCount > 0
                ? Badge(
                    label: Text(
                      _messageUnreadCount > 99 ? '99+' : '$_messageUnreadCount',
                    ),
                    child: const Icon(Icons.chat_bubble_outline),
                  )
                : const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: '消息',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
