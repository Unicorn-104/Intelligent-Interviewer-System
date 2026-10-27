import request from '@/utils/request'

export function createResume(data) {
  return request({
    url: '/agent/v1/resumes',
    method: 'post',
    data
  })
}

export function getResumes() {
  return request({
    url: '/agent/v1/resumes',
    method: 'get'
  })
}

export function getResume(resumeId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}`,
    method: 'get'
  })
}

export function updateResume(resumeId, data) {
  return request({
    url: `/agent/v1/resumes/${resumeId}`,
    method: 'put',
    data
  })
}

export function parseResumePdf(file) {
  const formData = new FormData()
  formData.append('file', file)
  return request({
    url: '/agent/v1/resumes/parse-pdf',
    method: 'post',
    data: formData,
    timeout: 120000
  }).then(response => {
    const data = response?.data
    if (!data || typeof data !== 'object') {
      throw new Error('PDF 解析响应格式不正确')
    }
    const hasStructuredContent = [
      data.jobDirection,
      data.realName,
      ...(Array.isArray(data.educations) ? data.educations : []),
      ...(Array.isArray(data.works) ? data.works : []),
      ...(Array.isArray(data.projects) ? data.projects : []),
      ...(Array.isArray(data.skills) ? data.skills : [])
    ].some(value => {
      if (typeof value === 'string') return value.trim().length > 0
      return value && typeof value === 'object'
    })
    if (!hasStructuredContent) {
      throw new Error('暂未识别到可用的简历信息，请上传更清晰的 PDF')
    }
    if (String(data.structureMethod || '').toUpperCase() !== 'AI') {
      const warnings = Array.isArray(data.parseWarnings) ? [...data.parseWarnings] : []
      if (!warnings.some(item => String(item).includes('规则识别'))) {
        warnings.unshift('当前为规则识别结果，请对照原始 PDF 仔细核对')
      }
      data.parseWarnings = warnings
    }
    return response
  })
}

export function importResumePdf(resumeId, resume, file) {
  const formData = new FormData()
  formData.append('resume', new Blob([JSON.stringify(resume)], { type: 'application/json' }), 'resume.json')
  formData.append('file', file)
  return request({
    url: resumeId ? `/agent/v1/resumes/${resumeId}/import-pdf` : '/agent/v1/resumes/import-pdf',
    method: 'post',
    data: formData,
    timeout: 120000
  })
}

export async function getResumeFile(resumeId) {
  const data = await request({
    url: `/agent/v1/resumes/${resumeId}/file`,
    method: 'get',
    responseType: 'blob',
    timeout: 30000
  })
  if (!(data instanceof Blob)) {
    throw new Error('原始 PDF 响应格式不正确')
  }
  const header = new TextDecoder().decode(await data.slice(0, 5).arrayBuffer())
  if (header !== '%PDF-') {
    let message = '原始 PDF 暂不可用，请刷新列表或稍后重试'
    try {
      const body = JSON.parse(await data.text())
      if (body?.msg) message = body.msg
    } catch (_) {}
    throw new Error(message)
  }
  return data
}
export function uploadResumeFile(resumeId, file) {
  const formData = new FormData()
  formData.append('file', file)
  return request({
    url: `/agent/v1/resumes/${resumeId}/file`,
    method: 'post',
    data: formData
  })
}

export function downloadResumeFile(resource) {
  return request({
    url: '/common/download/resource',
    method: 'get',
    params: { resource },
    responseType: 'blob'
  })
}

export function deleteResume(resumeId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}`,
    method: 'delete'
  })
}

export function getResumeAttachments(resumeId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}/attachments`,
    method: 'get'
  })
}

export function uploadResumeAttachments(resumeId, files) {
  const formData = new FormData()
  Array.from(files || []).forEach(file => formData.append('files', file, file.name))
  return request({
    url: `/agent/v1/resumes/${resumeId}/attachments`,
    method: 'post',
    data: formData,
    timeout: 120000
  })
}

export function getResumeAttachmentFile(resumeId, attachmentId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}/attachments/${attachmentId}/file`,
    method: 'get',
    responseType: 'blob',
    timeout: 30000
  })
}

export function deleteResumeAttachment(resumeId, attachmentId) {
  return request({
    url: `/agent/v1/resumes/${resumeId}/attachments/${attachmentId}`,
    method: 'delete'
  })
}