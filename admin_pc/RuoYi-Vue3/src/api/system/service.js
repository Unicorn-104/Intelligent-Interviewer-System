import request from '@/utils/request'

export function listPrivacy(query) {
  return request({ url: '/system/privacy/list', method: 'get', params: query })
}
export function updatePrivacy(data) {
  return request({ url: '/system/privacy', method: 'put', data: data })
}

export function listDataExport() {
  return request({ url: '/system/data/exportList', method: 'get' })
}
export function exportData(dataId) {
  return request({ url: '/system/data/export/' + dataId, method: 'post' })
}
export function deleteExportData(id) {
  return request({ url: '/system/data/' + id, method: 'delete' })
}

export function getThemeConfig() {
  return request({ url: '/system/theme/config', method: 'get' })
}
export function updateThemeConfig(data) {
  return request({ url: '/system/theme/config', method: 'put', data: data })
}

export function getMaintenanceInfo() {
  return request({ url: '/system/maintenance/info', method: 'get' })
}
export function clearCache() {
  return request({ url: '/system/maintenance/clearCache', method: 'post' })
}
export function reportError(data) {
  return request({ url: '/system/maintenance/report', method: 'post', data: data })
}
