import 'package:flutter/material.dart';

import '../features/auth/domain/auth_session.dart';
import '../features/companies/presentation/company_favorites_screen.dart';
import '../features/jobs/presentation/job_favorites_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        bottom: const TabBar(
          tabs: [
            Tab(text: '职位'),
            Tab(text: '企业'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          JobFavoritesScreen(session: session, showAppBar: false),
          CompanyFavoritesScreen(session: session, showAppBar: false),
        ],
      ),
    ),
  );
}
