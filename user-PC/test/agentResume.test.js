import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import { reactive, ref } from 'vue'
import { mergeParsedResume, profileResumeDefaults, resumeDate, resumeDegree, resumeSections } from '../src/utils/agentResume.js'

function editor(overrides = {}, search = '?id=new') {
  const script = fs.readFileSync(new URL('../src/views/agent/pages/resume-editor.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const dependencies = {
    reactive, ref, mergeParsedResume, profileResumeDefaults, resumeDate, resumeDegree, resumeSections,
    onMounted() {},
    window: { location: { search }, clearTimeout() {}, setTimeout() {}, confirm: () => true },
    getAppProfile: async () => ({ data: { realName: '资料姓名', sex: '1', phonenumber: '13800000000', currentStatus: 3, targetDirection: '开发工程师' } }),
    getResume: async () => ({ data: { id: 20, realName: '原简历姓名', educations: [], works: [], projects: [], skills: [] } }),
    getResumeAttachments: async () => ({ data: [] }),
    validateResumeFile: () => ({ valid: true }),
    ...overrides
  }
  return new Function(...Object.keys(dependencies), `${script}\nreturn { loadResume, resume, loading, toastMessage, applyParsedDraft, buildPayload, handlePdfChange, pendingPdf }`)(...Object.values(dependencies))
}

test('基础资料按明确字段映射，数字 sex=0 和求职状态不会漏填', () => {
  const defaults = profileResumeDefaults({ realName: ' 示例姓名 ', sex: 0, currentStatus: 2, phonenumber: '13800000000', email: 'test@example.invalid', currentCity: '上海', targetDirection: '开发', targetCity: '杭州' })
  assert.deepEqual(defaults, { realName: '示例姓名', gender: '男', workStatus: '离职-随时到岗', currentCity: '上海', phone: '13800000000', email: 'test@example.invalid', jobDirection: '开发', targetRole: '开发', targetCity: '杭州' })
  assert.equal(profileResumeDefaults({ nickName: '昵称', userName: '账号' }).realName, '')
  assert.equal(profileResumeDefaults({ sex: '2', currentStatus: 99 }).gender, '')
})

test('PDF 仅补充空白个人字段，保留基础资料、手动修改与附件标识', () => {
  const original = { id: 20, realName: '资料姓名', phone: '', jobDirection: '已选方向', fileUrl: '/file.pdf', attachments: [{ id: 7 }], projects: [{ name: '原项目' }] }
  const merged = mergeParsedResume(original, { id: 99, realName: 'PDF姓名', phone: '13800000000', jobDirection: 'PDF方向', fileUrl: '/other.pdf', attachments: [], educations: [{ school: '示例大学' }], projects: [] })
  assert.equal(merged.id, 20)
  assert.equal(merged.realName, '资料姓名')
  assert.equal(merged.phone, '13800000000')
  assert.equal(merged.jobDirection, '已选方向')
  assert.equal(merged.fileUrl, '/file.pdf')
  assert.deepEqual(merged.attachments, original.attachments)
  assert.deepEqual(merged.projects, original.projects)
  assert.equal(merged.educations[0].school, '示例大学')
})

test('日期适配 date 输入框，非法日期留空，学历覆盖中专大专且未知不猜本科', () => {
  assert.equal(resumeDate('2024-09-01T00:00:00+08:00'), '2024-09-01')
  assert.equal(resumeDate('2024年9月'), '2024-09-01')
  assert.equal(resumeDate('2024.9.2'), '2024-09-02')
  assert.equal(resumeDate('2024-02-30'), '')
  assert.equal(resumeDate('2024-13'), '')
  assert.equal(resumeDate('至今'), '')
  assert.equal(resumeDegree('2'), 2)
  assert.equal(resumeDegree(1), 1)
  assert.equal(resumeDegree(null), null)
  assert.equal(resumeDegree('未知'), null)
})

test('新建时等待基础资料并自动回填，不写数据库', async () => {
  const page = editor()
  assert.equal(page.loading.value, true)
  await page.loadResume()
  assert.equal(page.loading.value, false)
  assert.equal(page.resume.realName, '资料姓名')
  assert.equal(page.resume.gender, '女')
  assert.equal(page.resume.workStatus, '在校-寻找实习')
  assert.equal(page.resume.phone, '13800000000')
  assert.equal(page.resume.targetRole, '开发工程师')
})

test('编辑已有简历不读取基础资料，不覆盖已保存的个人信息', async () => {
  const page = editor({ getAppProfile: () => assert.fail('已有简历不应读取基础资料') }, '?id=20')
  await page.loadResume()
  assert.equal(page.resume.realName, '原简历姓名')
})

test('基础资料读取失败不阻塞手动新建', async () => {
  const page = editor({ getAppProfile: async () => { throw new Error('unavailable') } })
  await page.loadResume()
  assert.equal(page.loading.value, false)
  assert.equal(page.resume.realName, '')
  assert.match(page.toastMessage.value, /可手动填写/)
})

test('PDF 各栏目字段和日期保存时保持对应，原 PDF 暂存供保存附件', async () => {
  const page = editor()
  await page.loadResume()
  const file = { name: 'synthetic.pdf', size: 100 }
  page.applyParsedDraft({ educations: [{ school: '示例大学', major: '计算机', degree: 2, startDate: '2020-9-1', endDate: '2023-6-1' }], works: [{ company: '示例公司', position: '开发', current: true }], projects: [{ name: '示例项目', role: '开发者', techStack: 'Java' }], skills: [{ name: 'Java', level: null }], parseWarnings: ['请核对'] }, file)
  const payload = page.buildPayload()
  assert.equal(payload.educations[0].school, '示例大学')
  assert.equal(payload.educations[0].major, '计算机')
  assert.equal(payload.educations[0].degree, 2)
  assert.equal(payload.educations[0].startDate, '2020-09-01')
  assert.equal(payload.works[0].company, '示例公司')
  assert.equal(payload.projects[0].name, '示例项目')
  assert.equal(payload.projects[0].role, '开发者')
  assert.equal(payload.skills[0].level, null)
  assert.equal(payload.realName, '资料姓名')
  assert.ok(!('localId' in payload.educations[0]))
  assert.deepEqual(page.pendingPdf.value, file)
})

test('教育、实习工作和项目起止日期回填后保存不丢失，目前在职保留开始日期', async () => {
  const page = editor()
  await page.loadResume()
  page.applyParsedDraft({
    educations: [{ school: '示例大学', startDate: '2018-09-01', endDate: '2022-06-01' }],
    works: [
      { company: '实习公司', position: '实习生', startDate: '2021-07-01', endDate: '2021-09-01' },
      { company: '示例公司', position: '工程师', startDate: '2022-07-01', endDate: null, current: true }
    ],
    projects: [{ name: '示例项目', startDate: '2023-01-01', endDate: '2023-06-01' }]
  }, { name: 'synthetic.pdf', size: 100 })
  const payload = page.buildPayload()
  assert.equal(page.resume.educations[0].startDate, '2018-09-01')
  assert.equal(payload.educations[0].endDate, '2022-06-01')
  assert.equal(payload.works[0].startDate, '2021-07-01')
  assert.equal(payload.works[0].endDate, '2021-09-01')
  assert.equal(payload.works[1].startDate, '2022-07-01')
  assert.equal(payload.works[1].endDate, '')
  assert.equal(payload.works[1].current, true)
  assert.equal(payload.projects[0].startDate, '2023-01-01')
  assert.equal(payload.projects[0].endDate, '2023-06-01')
})

test('已有经历被 PDF 替换前可取消，取消后不改变内容和原 PDF', async () => {
  const page = editor({ parseResumePdf: async () => ({ data: { projects: [{ name: 'PDF项目' }] } }), window: { location: { search: '?id=new' }, confirm: () => false } })
  page.resume.projects = [{ name: '手填项目' }]
  await page.handlePdfChange({ target: { files: [{ name: 'synthetic.pdf' }], value: 'file' } })
  assert.equal(page.resume.projects[0].name, '手填项目')
  assert.equal(page.pendingPdf.value, null)
})

test('简历列表直接上传 PDF 同样以基础资料优先，发送真实导入接口所需的字段', async () => {
  let imported
  const file = { name: 'synthetic.pdf', size: 100 }
  const script = fs.readFileSync(new URL('../src/views/agent/pages/profile-resumes.vue', import.meta.url), 'utf8')
    .match(/<script setup>([\s\S]*?)<\/script>/)[1].replace(/^import .*$/gm, '')
  const dependencies = {
    ref, mergeParsedResume, profileResumeDefaults,
    onMounted() {}, onBeforeUnmount() {},
    window: { clearTimeout() {}, setTimeout() {} },
    validateResumeFile: () => ({ valid: true }),
    getAppProfile: async () => ({ data: { realName: '资料姓名', targetDirection: '后端研发', phonenumber: '13800000000' } }),
    parseResumePdf: async () => ({ data: { realName: 'PDF姓名', resumeName: 'PDF简历', educations: [{ school: '示例大学', degree: 2 }] } }),
    importResumePdf: async (resumeId, payload, originalFile) => { imported = { resumeId, payload, originalFile }; return { data: { id: 20 } } },
    getResumes: async () => ({ data: [] })
  }
  const page = new Function(...Object.keys(dependencies), `${script}\nreturn { handleFileChange }`)(...Object.values(dependencies))
  await page.handleFileChange({ target: { files: [file], value: 'file' } })
  assert.equal(imported.resumeId, null)
  assert.equal(imported.payload.realName, '资料姓名')
  assert.equal(imported.payload.targetRole, '后端研发')
  assert.equal(imported.payload.educations[0].school, '示例大学')
  assert.equal(imported.originalFile, file)
})
