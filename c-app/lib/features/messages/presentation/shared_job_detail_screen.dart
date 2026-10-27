import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';
import '../../../screens/job_detail_screen.dart';
import '../../auth/domain/auth_session.dart';
import '../../jobs/data/job_api.dart';
import '../../jobs/data/job_favorite_api.dart';

/// 始终读取求职者岗位接口，复用C-APP详情与本人投递接口。
class SharedJobDetailScreen extends StatefulWidget {
  const SharedJobDetailScreen({
    super.key,
    required this.positionId,
    required this.session,
    this.api,
    this.favoriteApi,
  });
  final int positionId;
  final AuthSession session;
  final JobApi? api;
  final JobFavoriteApi? favoriteApi;
  @override
  State<SharedJobDetailScreen> createState() => _SharedJobDetailScreenState();
}

class _SharedJobDetailScreenState extends State<SharedJobDetailScreen> {
  late final ApiClient client = ApiClient();
  late final JobApi api = widget.api ?? JobApi(client);
  late Future<Job> detail;
  bool submitting = false, uncertain = false;
  @override
  void initState() {
    super.initState();
    detail = api.fetchSharedJob(widget.session.token, widget.positionId);
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

  Future<bool> apply(Job job) async {
    if (submitting || uncertain) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认投递'),
        content: Text('将默认简历投递给「${job.company}」的“${job.title}”岗位？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不投递'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认投递'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return false;
    submitting = true;
    try {
      await api.apply(widget.session.token, job.positionId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投递成功')));
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => uncertain = error.code == null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uncertain ? '投递结果待核对，请返回投递记录确认，勿重复提交' : error.message,
            ),
          ),
        );
      }
      return false;
    } finally {
      submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Job>(
    future: detail,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(title: const Text('岗位详情')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('岗位详情')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : '岗位暂不可用，请稍后重试',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => detail = api.fetchSharedJob(
                        widget.session.token,
                        widget.positionId,
                      ),
                    ),
                    child: const Text('重新读取岗位'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return JobDetailScreen(
        job: snapshot.data!,
        favoriteApi: widget.favoriteApi,
        session: widget.session,
        onApply: uncertain ? null : apply,
      );
    },
  );
}
