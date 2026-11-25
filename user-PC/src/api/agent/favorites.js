import request from '@/utils/request'

export const listJobFavorites = params => request({ url: '/app/jobs/favorites', method: 'get', params })
export const getJobFavorite = positionId => request({ url: `/app/jobs/${positionId}/favorite`, method: 'get' })
export const setJobFavorite = (positionId, favorited) => request({ url: `/app/jobs/${positionId}/favorite`, method: 'put', data: { favorited } })
