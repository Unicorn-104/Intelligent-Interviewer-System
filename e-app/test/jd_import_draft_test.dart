import 'package:enterprise_recruiter/features/enterprise/jobs/models/jd_import_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/jd_import_fixture.dart';

void main() {
  test('技能 required=null 不转成必备，warnings 原文不裁剪', () {
    final draft = jdDraft();
    expect(draft.skills.last.requiredFlag, isNull);
    expect(draft.skills.last.requirementLabel, '未注明');
    expect(draft.skills.last.toJson(), {'name': 'Flutter', 'required': null});
    expect(draft.warnings, jdDraftJson()['warnings']);
    expect(() => draft.warnings.add('changed'), throwsUnsupportedError);
  });

  final invalid = <String, Map<String, dynamic>>{
    '岗位名称非文本': {'title': 123},
    '岗位名称过长': {'title': List.filled(101, '字').join()},
    '学历类型': {'education': '本科'},
    '学历下界': {'education': 0},
    '学历上界': {'education': 6},
    '工作性质类型': {'jobType': 1.5},
    '工作性质上界': {'jobType': 4},
    '薪资字符串': {'salaryMin': '15000'},
    '薪资为零': {'salaryMin': 0},
    '薪资负数': {'salaryMin': -1},
    '薪资三位小数': {'salaryMin': 15000.555},
    '薪资范围颠倒': {'salaryMin': 30000},
    '薪资超上限': {'salaryMax': 100000000},
    '薪资非有限数': {'salaryMin': double.nan},
    '职责非数组': {'responsibilities': 'text'},
    '要求数组含空白': {
      'requirements': [' '],
    },
    '技能非数组': {'skills': {}},
    '技能缺少required': {
      'skills': [
        {'name': 'Dart'},
      ],
    },
    '技能标识越界': {
      'skills': [
        {'name': 'Dart', 'required': 2},
      ],
    },
    '警告含非文本': {
      'warnings': [123],
    },
  };
  for (final entry in invalid.entries) {
    test('拒绝无效草稿：${entry.key}', () {
      expect(() => jdDraft(entry.value), throwsFormatException);
    });
  }

  test('缺少约定字段拒绝解析', () {
    final json = jdDraftJson()..remove('title');
    expect(() => JdImportDraft.fromJson(json), throwsFormatException);
  });

  test('空表单自动填入有值字段，不需要覆盖确认', () {
    final patch = jdDraft().prepareImport({});
    expect(patch.needsOverwriteConfirmation, isFalse);
    expect(patch.values['title'], jdDraftJson()['title']);
    expect(patch.values['salaryMin'], '15000.5');
    expect(patch.values['salaryMax'], '25000');
    expect(patch.values.keys, isNot(contains('summary')));
    expect(patch.values.keys, isNot(contains('softRequirements')));
    expect(patch.values.keys, isNot(contains('warnings')));
  });

  test('相同输入和等价薪资格式不覆盖', () {
    final draft = jdDraft();
    final current = {
      ...draft.prepareImport({}).values,
      'salaryMin': '15000.50',
    };
    final patch = draft.prepareImport(current);
    expect(patch.isEmpty, isTrue);
    expect(patch.needsOverwriteConfirmation, isFalse);
  });

  test('覆盖差异依据应用时的最新输入计算', () {
    final draft = jdDraft();
    final current = {
      ...draft.prepareImport({}).values,
      'title': '解析期间刚编辑',
      'city': '北京',
    };
    final patch = draft.prepareImport(current);
    expect(patch.overwrittenFields, ['title', 'city']);
    expect(patch.overwrittenLabels, ['岗位名称', '工作城市']);
    expect(current['title'], '解析期间刚编辑');
  });

  test('缺失标量和空数组保留原表单字段', () {
    final draft = jdDraft({
      'title': null,
      'salaryMin': null,
      'salaryMax': null,
      'requirements': [],
      'skills': [],
    });
    final patch = draft.prepareImport({
      'title': '保留岗位',
      'salaryMin': '8000',
      'salaryMax': '12000',
      'requirements': ['保留要求'],
      'skills': [
        {'name': 'Java', 'required': 0},
      ],
    });
    for (final key in [
      'title',
      'salaryMin',
      'salaryMax',
      'requirements',
      'skills',
    ]) {
      expect(patch.values.containsKey(key), isFalse, reason: key);
    }
  });

  for (final missing in ['salaryMin', 'salaryMax']) {
    test('单边薪资 $missing 作为整组替换，缺失端留空', () {
      final draft = jdDraft({missing: null});
      final patch = draft.prepareImport({
        'salaryMin': '8000',
        'salaryMax': '12000',
      });
      expect(draft.hasPartialSalary, isTrue);
      expect(patch.values[missing], '');
      expect(patch.values.keys, containsAll(['salaryMin', 'salaryMax']));
      expect(patch.overwrittenFields, ['salary']);
    });
  }

  test('薪资面议改成已识别金额需要确认', () {
    final patch = jdDraft().prepareImport({'negotiable': true});
    expect(patch.overwrittenFields, ['salary']);
  });

  test('自定义经验保留，不映射成其他年限', () {
    final draft = jdDraft({'experience': '三年以上复杂项目经验'});
    expect(draft.prepareImport({}).values['experience'], '三年以上复杂项目经验');
  });

  test('用户主动选择后才把摘要和软性要求追加进正文', () {
    final draft = jdDraft();
    final plain = draft.prepareImport({});
    expect(plain.values['responsibilities'], ['开发移动端功能', '编写自动化测试']);
    expect(plain.values['requirements'], ['熟悉 Dart']);
    final appended = draft.prepareImport(
      {},
      appendSummary: true,
      appendSoftRequirements: true,
    );
    expect(appended.values['responsibilities'], [
      '开发移动端功能',
      '编写自动化测试',
      '维护合成测试应用',
    ]);
    expect(appended.values['requirements'], ['熟悉 Dart', '团队协作']);
  });

  test('追加不会重复相同条目，也不清空文档未提供的已有正文', () {
    final draft = jdDraft({'responsibilities': [], 'requirements': []});
    final patch = draft.prepareImport(
      {
        'responsibilities': ['维护合成测试应用'],
        'requirements': ['团队协作'],
      },
      appendSummary: true,
      appendSoftRequirements: true,
    );
    expect(patch.isEmpty, isFalse);
    expect(patch.values.containsKey('responsibilities'), isFalse);
    expect(patch.values.containsKey('requirements'), isFalse);
  });

  test('追加后正文超限拒绝而不截断', () {
    final draft = jdDraft({
      'responsibilities': List.generate(30, (index) => '职责$index'),
    });
    expect(
      () => draft.prepareImport({}, appendSummary: true),
      throwsFormatException,
    );
  });
}
