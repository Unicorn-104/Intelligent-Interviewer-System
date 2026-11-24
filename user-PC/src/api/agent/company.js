import request from '@/utils/request'

export const getCompany = companyId => request({ url: `/app/companies/${companyId}`, method: 'get' })
export const getCompanyJobs = (companyId, params) => request({ url: `/app/companies/${companyId}/jobs`, method: 'get', params })
export const setCompanyFollowed = (companyId, followed) => request({ url: `/app/companies/${companyId}/follow`, method: 'put', data: { followed } })
export const getRecruiter = contactId => request({ url: `/agent/v1/contacts/${contactId}`, method: 'get' })
