// API contract placeholders. Replace reserveApi with the shared HTTP client when the backend is ready.
export const api = {
  positions: {
    list: { method: 'GET', path: '/api/v1/positions/my', params: ['status', 'keyword', 'page', 'pageSize'] },
    detail: { method: 'GET', path: '/api/v1/positions/{positionId}', params: ['positionId'] },
    parseJd: { method: 'POST', path: '/api/v1/positions/parse-jd', body: ['jdText'] },
    create: { method: 'POST', path: '/api/v1/positions', body: ['title', 'department', 'workCity', 'salaryMin', 'salaryMax', 'experienceRequired', 'educationRequired', 'jobType', 'jdProfile', 'skills'] },
    workflow: { method: 'GET', path: '/api/v1/positions/{positionId}/workflow', params: ['positionId'] },
    saveWorkflow: { method: 'PUT', path: '/api/v1/positions/{positionId}/workflow', body: ['mode', 'stages', 'transitions', 'notificationTemplateIds'] },
    versions: { method: 'GET', path: '/api/v1/positions/{positionId}/versions', params: ['positionId', 'page', 'pageSize'] },
    duplicate: { method: 'POST', path: '/api/v1/positions/{positionId}/duplicate', body: ['title'] }
  },
  candidates: {
    list: { method: 'GET', path: '/api/v1/enterprise/talent-pool', params: ['keyword', 'status', 'tag', 'page', 'pageSize'] },
    detail: { method: 'GET', path: '/api/v1/candidates/{candidateId}', params: ['candidateId'] },
    status: { method: 'PATCH', path: '/api/v1/candidates/{candidateId}/status', body: ['status', 'remark'] },
    statusHistory: { method: 'GET', path: '/api/v1/candidates/{candidateId}/status-history', params: ['candidateId', 'page', 'pageSize'] },
    tags: { method: 'GET/POST/DELETE', path: '/api/v1/candidates/{candidateId}/tags', body: ['name', 'color'] },
    batchTags: { method: 'POST', path: '/api/v1/candidates/tags/batch', body: ['candidateIds', 'tagId', 'action'] },
    rounds: { method: 'GET', path: '/api/v1/applications/{applicationId}/rounds', params: ['applicationId'] },
    advance: { method: 'POST', path: '/api/v1/applications/{applicationId}/rounds/advance', body: ['fromRound', 'reason'] }
  },
  scheduling: {
    slots: { method: 'GET/POST/DELETE', path: '/api/v1/interviewer-slots', body: ['positionId', 'startTime', 'endTime'] },
    invitations: { method: 'POST/GET', path: '/api/v1/interview-invitations', body: ['applicationId', 'interviewerId', 'templateId', 'slotId', 'expiresAt'] },
    recommend: { method: 'POST', path: '/api/v1/interview-slots/recommend', body: ['applicationId', 'interviewerId', 'candidateAvailability', 'durationMinutes'] },
    appointments: { method: 'GET/POST/PATCH', path: '/api/v1/interview-appointments', body: ['invitationId', 'slotId', 'reason', 'cancelBy'] },
    roundsSchedule: { method: 'POST', path: '/api/v1/applications/{applicationId}/rounds/schedule', body: ['stageId', 'interviewerIds', 'preferredSlots'] }
  },
  sessions: {
    progress: { method: 'GET', path: '/api/v1/interview-sessions/{sessionId}/progress', params: ['sessionId'] },
    currentQuestion: { method: 'GET', path: '/api/v1/interview-sessions/{sessionId}/questions/current', params: ['sessionId'] },
    answer: { method: 'POST', path: '/api/v1/interview-sessions/{sessionId}/answers', body: ['questionId', 'answerType', 'content', 'clientRequestId'] },
    finish: { method: 'POST', path: '/api/v1/interview-sessions/{sessionId}/finish', body: ['endReason', 'clientRequestId'] },
    environment: { method: 'POST', path: '/api/v1/interview-sessions/{sessionId}/environment-check', body: ['checks'] },
    meetingMedia: { method: 'PATCH', path: '/api/v1/interview-sessions/{sessionId}/meeting/media', body: ['microphoneEnabled', 'cameraEnabled', 'speakerVolume', 'deviceIds'] },
    captions: { method: 'GET', path: '/api/v1/interview-sessions/{sessionId}/captions', params: ['afterSequence', 'limit'] },
    copilot: { method: 'GET/POST', path: '/api/v1/interview-sessions/{sessionId}/copilot', body: ['mode', 'content', 'afterSequence'] },
    takeover: { method: 'POST', path: '/api/v1/interview-sessions/{sessionId}/takeover', body: ['action', 'reason'] },
    scorecard: { method: 'GET', path: '/api/v1/interview-sessions/{sessionId}/scorecard', params: ['sessionId'] },
    evaluation: { method: 'GET/POST/PATCH', path: '/api/v1/interview-sessions/{sessionId}/evaluation', body: ['dimensionScores', 'overallScore', 'recommendation', 'summary', 'advantages', 'risks', 'gaps', 'clientRequestId'] },
    publishEvaluation: { method: 'POST', path: '/api/v1/interview-sessions/{sessionId}/evaluation/publish', body: ['recommendation', 'comment', 'notifyCandidate'] },
    cascade: { method: 'POST', path: '/api/v1/interview-sessions/{sessionId}/cascade/evaluate', body: ['decision', 'reason'] }
  },
  messaging: {
    notifications: { method: 'GET', path: '/api/v1/notification/list', params: ['status', 'type', 'page', 'pageSize'] },
    markRead: { method: 'PATCH', path: '/api/v1/notification/{notificationId}/read', body: ['notificationId'] },
    conversations: { method: 'GET/POST/PATCH/DELETE', path: '/api/v1/conversations', body: ['targetUserId', 'contextType', 'contextId', 'isPinned', 'muted'] },
    messages: { method: 'GET/POST', path: '/api/v1/conversations/{conversationId}/messages', body: ['type', 'content', 'clientRequestId'] },
    templates: { method: 'GET/POST/PATCH/DELETE', path: '/api/v1/message-templates', body: ['name', 'type', 'channels', 'content', 'variables', 'status'] }
  },
  account: {
    profile: { method: 'GET/PATCH', path: '/api/v1/hr/me', body: ['nickName', 'email', 'phone', 'department', 'jobTitle'] },
    password: { method: 'PUT', path: '/api/v1/auth/password', body: ['oldPassword', 'newPassword'] },
    sessions: { method: 'GET/DELETE', path: '/api/v1/auth/sessions/{sessionId}', params: ['sessionId'] },
    settings: { method: 'GET/PATCH', path: '/api/v1/users/me/settings', body: ['uiTheme', 'language', 'reducedMotion'] }
  }
}

export function reserveApi(contract, payload = {}) {
  // The UI remains mock-backed until the API client is connected.
  console.info(`[API reserved] ${contract.method} ${contract.path}`, payload)
  return { contract, payload }
}
