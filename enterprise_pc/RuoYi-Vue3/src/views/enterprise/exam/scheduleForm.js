// 考试安排表单的默认值与提交结构，供「考试安排」「投递流程」「消息中心」三处复用
export function blankScheduleForm() {
  return {
    paperId: '', startAt: '', endAt: '', maxAttempts: 1, passThreshold: 60,
    forceDualCamera: 0, dualAngle: '侧后方 45°，须拍到桌面与双手', dualNote: '',
    autoSubmit: true, allowEarly: true, autosaveInterval: 30,
    autoInterviewerId: '', autoInviteDays: 3, autoInviteDuration: 45
  }
}

export function schedulePayload(form, options = {}) {
  const dual = Number(form.forceDualCamera) ? 1 : 0
  return {
    positionId: options.positionId,
    stageId: options.stageId ?? form.stageId ?? null,
    paperId: Number(options.paperId ?? form.paperId),
    startAt: String(form.startAt || '').replace('T', ' '),
    endAt: String(form.endAt || '').replace('T', ' '),
    maxAttempts: Number(form.maxAttempts) || 1,
    passThreshold: Number(form.passThreshold) || 60,
    forceDualCamera: dual,
    dualCameraConfig: dual ? { angle: form.dualAngle || '', note: form.dualNote || '' } : null,
    submitRule: {
      autoSubmit: form.autoSubmit !== false,
      allowEarly: form.allowEarly !== false,
      autosaveInterval: Number(form.autosaveInterval) || 30
    },
    autoFlow: form.autoInterviewerId ? {
      interviewerId: Number(form.autoInterviewerId),
      startAfterDays: Number(form.autoInviteDays) || 3,
      durationMin: Number(form.autoInviteDuration) || 45
    } : null
  }
}
