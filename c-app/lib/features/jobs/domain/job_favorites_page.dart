import '../../../core/network/api_exception.dart';
import '../../../models/job.dart';

class JobFavoritesPage {
  const JobFavoritesPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasNext,
  });

  final List<Job> items;
  final int page, total;
  final bool hasNext;

  factory JobFavoritesPage.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List ||
        json['page'] is! int ||
        (json['page'] as int) < 1 ||
        json['total'] is! int ||
        (json['total'] as int) < 0 ||
        json['hasNext'] is! bool) {
      throw const ApiException('收藏列表格式不正确，请重试');
    }
    return JobFavoritesPage(
      items: (json['items'] as List).map((item) {
        if (item is! Map) throw const ApiException('职位信息格式不正确，请重试');
        final job = Job.fromJson(Map<String, dynamic>.from(item));
        if (job.positionId <= 0) {
          throw const ApiException('职位信息格式不正确，请重试');
        }
        return job;
      }).toList(),
      page: json['page'] as int,
      total: json['total'] as int,
      hasNext: json['hasNext'] as bool,
    );
  }
}
