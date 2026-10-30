import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_interviewer/features/interviews/domain/conference_readiness.dart';

void main() {
  test(
    'candidate ready does not imply interviewer ready or session started',
    () {
      final state = ConferenceReadiness.fromJson(
        {
          'sessionStatus': 0,
          'selfReady': true,
          'peerReady': false,
          'participants': [
            {'userId': 12, 'role': 2, 'ready': 1},
          ],
        },
        {},
        12,
      );
      expect(state.selfReady, true);
      expect(state.selfLabel, '已就绪');
      expect(state.peerReady, false);
      expect(state.peerLabel, '尚未进入本场等候室');
      expect(state.hint, contains('你已就绪'));
    },
  );
  test(
    'interviewer ready is read from participant rows despite stale last-peer flag',
    () {
      final state = ConferenceReadiness.fromJson(
        {
          'selfReady': true,
          'peerReady': false,
          'participants': [
            {'userId': 12, 'role': 2, 'ready': 1},
            {'userId': 20, 'role': 1, 'ready': 1},
            {'userId': 30, 'role': 3, 'ready': 0},
          ],
        },
        {
          'interviewers': [
            {'userId': 20},
          ],
        },
        12,
      );
      expect(state.peerReady, true);
      expect(state.peerLabel, '已就绪');
      expect(state.hint, contains('等待面试官开始'));
    },
  );
  test(
    'unassigned participant cannot make the assigned interviewer appear ready',
    () {
      final state = ConferenceReadiness.fromJson(
        {
          'selfReady': true,
          'peerReady': true,
          'participants': [
            {'userId': 12, 'role': 2, 'ready': 1},
            {'userId': 20, 'role': 1, 'ready': 0},
            {'userId': 30, 'role': 1, 'ready': 1},
          ],
        },
        {
          'interviewers': [
            {'userId': 20},
          ],
        },
        12,
      );
      expect(state.peerPresent, true);
      expect(state.peerReady, false);
      expect(state.peerLabel, '已进入，等待就绪');
    },
  );
  test('numeric and string flags in older responses remain supported', () {
    final state = ConferenceReadiness.fromJson(
      {'selfReady': 1, 'peerReady': '1'},
      {},
      12,
    );
    expect(state.selfReady, true);
    expect(state.peerReady, true);
    expect(state.hint, contains('双方已就绪'));
  });
  test(
    'empty response is a pending check rather than an offline interviewer',
    () {
      final state = ConferenceReadiness.fromJson({}, {}, 12);
      expect(state.confirmed, false);
      expect(state.peerLabel, '正在确认状态');
    },
  );
}
