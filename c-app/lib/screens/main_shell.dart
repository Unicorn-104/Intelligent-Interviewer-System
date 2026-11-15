import 'package:flutter/material.dart';

import '../features/auth/domain/auth_session.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'resume_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.session,
    required this.onLogin,
    required this.onLogout,
  });

  final AuthSession? session;
  final VoidCallback onLogin;
  final Future<void> Function() onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _messageUnreadCount = 0;
  int _messageRefreshVersion = 0;
  int _profileRefreshVersion = 0;

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.token != widget.session?.token) {
      _index = 0;
      _messageUnreadCount = 0;
      _messageRefreshVersion = 0;
      _profileRefreshVersion = 0;
    }
  }

  void _selectTab(int index) => setState(() {
    if (widget.session == null && index != 0) {
      _showLoginRequired();
      return;
    }
    _index = index;
    if (index == 2) _messageRefreshVersion++;
    if (index == 3) _profileRefreshVersion++;
  });

  Future<void> _showLoginRequired() async {
    final login = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('请先登录'),
        content: const Text('登录后才可以查看简历、投递、面试和个人中心。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('不了'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('登录'),
          ),
        ],
      ),
    );
    if (login == true && mounted) widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        // Recreate controllers and discard pending data when authentication changes.
        key: ObjectKey(widget.session),
        session: widget.session,
        onLoginRequired: _showLoginRequired,
        onOpenMessages: () => _selectTab(2),
        unreadCount: _messageUnreadCount,
      ),
      if (widget.session != null) ResumeScreen(session: widget.session!),
      if (widget.session != null)
        MessagesScreen(
          session: widget.session!,
          refreshVersion: _messageRefreshVersion,
          onUnreadChanged: (count) {
            if (_messageUnreadCount != count) {
              setState(() => _messageUnreadCount = count);
            }
          },
        ),
      if (widget.session != null)
        ProfileScreen(
          session: widget.session!,
          onLogout: widget.onLogout,
          refreshVersion: _profileRefreshVersion,
        ),
    ];
    final visibleIndex = _index < pages.length ? _index : 0;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: visibleIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: visibleIndex,
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
