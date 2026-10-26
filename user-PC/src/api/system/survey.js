import request from '@/utils/request'

// 候选人按匿名令牌读取问卷填写内容（无需登录）
export function getSurveyFill(token) {
  return request({
    url: '/system/survey/fill',
    method: 'get',
    params: { token: token }
  })
}

// 候选人按匿名令牌提交问卷作答
export function submitSurveyFill(data) {
  return request({
    url: '/system/survey/fill',
    method: 'post',
    data: data
  })
}
