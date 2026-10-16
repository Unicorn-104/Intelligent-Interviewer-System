import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/jobs/data/job_favorite_api.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_favorites_page.dart';
import 'package:intelligent_interviewer/models/job.dart';

Job favoriteJob(int id, {bool available = true}) => Job.fromJson({
  'positionId': id,
  'companyId': 7,
  'title': '合成岗位 $id',
  'company': '合成企业',
  'city': '北京',
  'available': available,
});

JobFavoritesPage favoritePage(
  List<Job> items, {
  int page = 1,
  bool next = false,
}) => JobFavoritesPage(
  items: items,
  page: page,
  total: next ? 30 : items.length,
  hasNext: next,
);

class FakeJobFavoriteApi extends JobFavoriteApi {
  FakeJobFavoriteApi() : super(ApiClient());
  bool favorited = false;
  Future<bool> Function()? onState;
  Future<bool> Function(int, bool)? onSave;
  Future<JobFavoritesPage> Function(int)? onPage;
  final saves = <(int, bool)>[];
  final pages = <int>[];

  @override
  Future<bool> state(String token, int positionId) async =>
      onState == null ? favorited : await onState!();

  @override
  Future<bool> setFavorited(String token, int positionId, bool value) async {
    saves.add((positionId, value));
    favorited = onSave == null ? value : await onSave!(positionId, value);
    return favorited;
  }

  @override
  Future<JobFavoritesPage> favorites(String token, {int page = 1}) async {
    pages.add(page);
    return onPage == null ? favoritePage([]) : await onPage!(page);
  }
}
