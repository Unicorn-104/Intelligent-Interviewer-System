import 'package:flutter/material.dart';
import 'package:enterprise_recruiter/core/network/api_client.dart';
import 'package:enterprise_recruiter/features/auth/auth_controller.dart';
import 'package:enterprise_recruiter/features/enterprise/enterprise_repository.dart';
import 'package:enterprise_recruiter/features/enterprise/jobs/mock_jobs.dart'
    as jobs;
import 'package:enterprise_recruiter/features/enterprise/talent/mock_talent.dart'
    as talent;
import 'package:enterprise_recruiter/features/enterprise/notification/mock_notification.dart'
    as notifications;
import 'package:enterprise_recruiter/features/enterprise/screening/mock_screening.dart'
    as screening;
import 'package:enterprise_recruiter/features/enterprise/interview/mock_execution.dart'
    as execution;
import 'package:enterprise_recruiter/features/auth/login_screen.dart' as p0;
import 'package:enterprise_recruiter/features/enterprise/dashboard/overview_page.dart'
    as p1;
import 'package:enterprise_recruiter/features/enterprise/enterprise_shell.dart'
    as p2;
import 'package:enterprise_recruiter/features/enterprise/interview/device_check_page.dart'
    as p3;
import 'package:enterprise_recruiter/features/enterprise/interview/interview_entrance_page.dart'
    as p4;
import 'package:enterprise_recruiter/features/enterprise/interview/interview_page.dart'
    as p5;
import 'package:enterprise_recruiter/features/enterprise/interview/interview_workbench_page.dart'
    as p6;
import 'package:enterprise_recruiter/features/enterprise/interview/practice_preload_page.dart'
    as p7;
import 'package:enterprise_recruiter/features/enterprise/interview/recording_page.dart'
    as p8;
import 'package:enterprise_recruiter/features/enterprise/jobs/job_detail_page.dart'
    as p9;
import 'package:enterprise_recruiter/features/enterprise/jobs/job_publish_page.dart'
    as p10;
import 'package:enterprise_recruiter/features/enterprise/jobs/jobs_page.dart'
    as p11;
import 'package:enterprise_recruiter/features/enterprise/login_page.dart'
    as p12;
import 'package:enterprise_recruiter/features/enterprise/notification/assistant_placeholder_page.dart'
    as p13;
import 'package:enterprise_recruiter/features/enterprise/notification/message_center_page.dart'
    as p14;
import 'package:enterprise_recruiter/features/enterprise/notification/notice_page.dart'
    as p15;
import 'package:enterprise_recruiter/features/enterprise/notification/notification_log_page.dart'
    as p16;
import 'package:enterprise_recruiter/features/enterprise/notification/notification_page.dart'
    as p17;
import 'package:enterprise_recruiter/features/enterprise/notification/notification_templates_page.dart'
    as p18;
import 'package:enterprise_recruiter/features/enterprise/notification/survey_result_page.dart'
    as p19;
import 'package:enterprise_recruiter/features/enterprise/offer/offer_page.dart'
    as p20;
import 'package:enterprise_recruiter/features/enterprise/profile/account_page.dart'
    as p21;
import 'package:enterprise_recruiter/features/enterprise/profile/settings_page.dart'
    as p22;
import 'package:enterprise_recruiter/features/enterprise/review/evaluation_report_page.dart'
    as p23;
import 'package:enterprise_recruiter/features/enterprise/review/review_page.dart'
    as p24;
import 'package:enterprise_recruiter/features/enterprise/schedule/interview_appointment_detail_page.dart'
    as p25;
import 'package:enterprise_recruiter/features/enterprise/schedule/interview_schedule_page.dart'
    as p26;
import 'package:enterprise_recruiter/features/enterprise/schedule/interviewer_calendar_page.dart'
    as p27;
import 'package:enterprise_recruiter/features/enterprise/schedule/reschedule_review_page.dart'
    as p28;
import 'package:enterprise_recruiter/features/enterprise/schedule/schedule_page.dart'
    as p29;
import 'package:enterprise_recruiter/features/enterprise/screening/candidate_score_detail_page.dart'
    as p30;
import 'package:enterprise_recruiter/features/enterprise/screening/greeting_page.dart'
    as p31;
import 'package:enterprise_recruiter/features/enterprise/screening/recommendation_report_page.dart'
    as p32;
import 'package:enterprise_recruiter/features/enterprise/screening/screening_page.dart'
    as p33;
import 'package:enterprise_recruiter/features/enterprise/screening/screening_results_page.dart'
    as p34;
import 'package:enterprise_recruiter/features/enterprise/screening/screening_task_list_page.dart'
    as p35;
import 'package:enterprise_recruiter/features/enterprise/screening/shortlist_review_page.dart'
    as p36;
import 'package:enterprise_recruiter/features/enterprise/talent/talent_detail_page.dart'
    as p37;
import 'package:enterprise_recruiter/features/enterprise/talent/talent_page.dart'
    as p38;
import 'package:enterprise_recruiter/p1_preview_main.dart' as p39;
import 'package:enterprise_recruiter/p2_preview_main.dart' as p40;
import 'package:enterprise_recruiter/p3_preview_main.dart' as p41;
import 'package:enterprise_recruiter/p4_preview_main.dart' as p42;
import 'package:enterprise_recruiter/p5_preview_main.dart' as p43;
import 'package:enterprise_recruiter/p7_pilot_main.dart' as p44;
import 'package:enterprise_recruiter/screens/dashboard_screen.dart' as p45;
import 'package:enterprise_recruiter/screens/jobs_screen.dart' as p46;
import 'package:enterprise_recruiter/screens/main_shell.dart' as p47;
import 'package:enterprise_recruiter/screens/messages_screen.dart' as p48;
import 'package:enterprise_recruiter/screens/profile_screen.dart' as p49;
import 'package:enterprise_recruiter/screens/settings_screen.dart' as p50;
import 'package:enterprise_recruiter/screens/talent_screen.dart' as p51;

/// Every page that existed before stage one, including legacy and preview routes.
class ExistingPages {
  final client = ApiClient();
  late final auth = AuthController(client);
  late final repository = EnterpriseRepository(
    client,
    () => 'synthetic-session',
  );

  Map<String, Widget Function()> get builders => {
    'LoginScreen': () => p0.LoginScreen(controller: auth),
    'OverviewPage': () => p1.OverviewPage(),
    'EnterpriseModuleShell': () => p2.EnterpriseModuleShell(onLogout: () {}),
    'DeviceCheckPage': () => p3.DeviceCheckPage(),
    'InterviewEntrancePage': () => p4.InterviewEntrancePage(),
    'InterviewPage': () => p5.InterviewPage(),
    'InterviewWorkbenchPage': () => p6.InterviewWorkbenchPage(),
    'PracticePreloadPage': () => p7.PracticePreloadPage(),
    'RecordingPage': () => p8.RecordingPage(),
    'JobDetailPage': () => p9.JobDetailPage(
      job: {...jobs.mockJobs.first, 'posId': 1, 'applicants': 0},
    ),
    'JobPublishPage': () => p10.JobPublishPage(
      loadOptions: () async => {
        'company': {'id': 1, 'name': '示例企业'},
        'departments': ['研发'],
      },
    ),
    'JobsPage': () => p11.JobsPage(),
    'LoginPage': () =>
        p12.LoginPage(authenticatedBuilder: (_, _) => const SizedBox.shrink()),
    'AssistantPlaceholderPage': () => p13.AssistantPlaceholderPage(),
    'MessageCenterPage': () => p14.MessageCenterPage(),
    'ChatPage': () => p14.ChatPage(session: notifications.mockImSessions.first),
    'NoticePage': () => p15.NoticePage(),
    'NotificationLogPage': () => p16.NotificationLogPage(),
    'NotificationPage': () => p17.NotificationPage(),
    'NotificationTemplatesPage': () => p18.NotificationTemplatesPage(),
    'SurveyResultPage': () => p19.SurveyResultPage(),
    'OfferPage': () => p20.OfferPage(),
    'AccountPage': () => p21.AccountPage(onLogout: () {}),
    'EnterpriseSettingsPage': () => p22.EnterpriseSettingsPage(),
    'EvaluationReportPage': () =>
        p23.EvaluationReportPage(review: execution.mockPendingReviews.first),
    'ReviewPage': () => p24.ReviewPage(),
    'InterviewAppointmentDetailPage': () => p25.InterviewAppointmentDetailPage(
      appointment: {
        'appointmentId': 1,
        'candidateName': '示例候选人',
        'positionTitle': '示例岗位',
        'positionId': 1,
        'startTime': '2026-10-16 10:00',
        'status': 0,
      },
    ),
    'RealInterviewSchedulePage': () => p26.RealInterviewSchedulePage(),
    'InterviewSchedulePage': () => p26.InterviewSchedulePage(),
    'InterviewerCalendarPage': () => p27.InterviewerCalendarPage(),
    'RescheduleReviewPage': () => p28.RescheduleReviewPage(),
    'SchedulePage': () => p29.SchedulePage(),
    'CandidateScoreDetailPage': () => p30.CandidateScoreDetailPage(
      candidate: screening.mockScreeningResults.first,
    ),
    'GreetingPage': () => p31.GreetingPage(),
    'RecommendationReportPage': () => p32.RecommendationReportPage(
      candidate: screening.mockScreeningResults.first,
    ),
    'ScreeningPage': () => p33.ScreeningPage(),
    'ScreeningResultsPage': () =>
        p34.ScreeningResultsPage(task: screening.mockScreeningTasks.first),
    'ScreeningTaskListPage': () => p35.ScreeningTaskListPage(),
    'ShortlistReviewPage': () => p36.ShortlistReviewPage(),
    'TalentDetailPage': () => p37.TalentDetailPage(
      talent: {...talent.mockTalents.first, 'talentId': 1},
    ),
    'TalentPage': () => p38.TalentPage(),
    'P1PreviewShell': () => p39.P1PreviewShell(),
    'P2PreviewShell': () => p40.P2PreviewShell(),
    'P3PreviewShell': () => p41.P3PreviewShell(),
    'P4PreviewShell': () => p42.P4PreviewShell(),
    'P5PreviewShell': () => p43.P5PreviewShell(),
    'P7PilotPage': () => p44.P7PilotPage(),
    'DashboardScreen': () => p45.DashboardScreen(
      repository: repository,
      displayName: '示例招聘经理',
      onOpenJobs: () {},
    ),
    'JobsScreen': () => p46.JobsScreen(repository: repository),
    'MainShell': () => p47.MainShell(auth: auth, repository: repository),
    'MessagesScreen': () => p48.MessagesScreen(repository: repository),
    'ChatScreen': () => p48.ChatScreen(
      repository: repository,
      session: {'sessionId': 1, 'name': '示例候选人'},
    ),
    'ProfileScreen': () =>
        p49.ProfileScreen(repository: repository, auth: auth),
    'SettingsScreen': () => p50.SettingsScreen(repository: repository),
    'TalentScreen': () => p51.TalentScreen(repository: repository),
  };

  void dispose() {
    auth.dispose();
    client.close();
  }
}
