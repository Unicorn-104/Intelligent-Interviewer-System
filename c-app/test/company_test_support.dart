import 'package:intelligent_interviewer/core/network/api_client.dart';
import 'package:intelligent_interviewer/features/auth/domain/auth_session.dart';
import 'package:intelligent_interviewer/features/companies/data/company_api.dart';
import 'package:intelligent_interviewer/features/companies/domain/company.dart';
import 'package:intelligent_interviewer/features/jobs/domain/job_search.dart';
import 'package:intelligent_interviewer/models/job.dart';

const session = AuthSession(
  token: 'synthetic-session',
  userId: 17,
  userName: 'synthetic',
  nickName: 'Test',
);
const company = Company(
  id: 7,
  name: '用于验证长名称布局的合成企业信息科技有限公司',
  followed: false,
  city: '杭州',
  verified: true,
);
Job job(int id) => Job.fromJson({
  'positionId': id,
  'companyId': 7,
  'title': 'Synthetic job',
  'company': company.name,
});
JobSearchPage page(List<Job> jobs, int number, bool next) => JobSearchPage(
  items: jobs,
  page: number,
  size: 10,
  total: 12,
  hasNext: next,
);

class FakeCompanyApi extends CompanyApi {
  FakeCompanyApi() : super(ApiClient());
  Future<Company> Function()? onDetail;
  Future<JobSearchPage> Function(int)? onJobs;
  Future<bool> Function(bool)? onFollow;
  final followValues = <bool>[];
  final jobPages = <int>[];
  @override
  Future<Company> detail(String token, int id) async =>
      onDetail == null ? company : await onDetail!();
  @override
  Future<JobSearchPage> jobs(String token, int id, {int page = 1}) async {
    jobPages.add(page);
    return onJobs == null
        ? JobSearchPage(
            items: [],
            page: page,
            size: 10,
            total: 0,
            hasNext: false,
          )
        : await onJobs!(page);
  }

  @override
  Future<bool> setFollowed(String token, int id, bool followed) async {
    followValues.add(followed);
    return onFollow == null ? followed : await onFollow!(followed);
  }
}
