import axios from 'axios'
import { ElNotification , ElMessageBox, ElMessage, ElLoading } from 'element-plus'
import { getToken, setToken, getRefreshToken, setRefreshToken, removeToken, removeRefreshToken } from '@/utils/auth'
import errorCode from '@/utils/errorCode'
import { tansParams, blobValidate } from '@/utils/ruoyi'
import cache from '@/plugins/cache'
import { saveAs } from 'file-saver'
import useUserStore from '@/store/modules/user'

let downloadLoadingInstance;
// 是否显示重新登录
export let isRelogin = { show: false };

// 静默刷新令牌的进行中请求，用于并发 401 时共用同一次刷新
let refreshing = null;

// 弹出重新登录提示
function handleReLogin() {
  if (!isRelogin.show) {
    isRelogin.show = true;
    ElMessageBox.confirm('登录状态已过期，您可以继续留在该页面，或者重新登录', '系统提示', { confirmButtonText: '重新登录', cancelButtonText: '取消', type: 'warning' }).then(() => {
      isRelogin.show = false;
      const userStore = useUserStore();
      // 登出接口同样可能因令牌失效而失败，此时也必须清空本地令牌，
      // 否则跳转后被路由守卫再次拦回，页面会卡在加载态
      userStore.logOut().catch(() => {
        removeToken();
        removeRefreshToken();
        userStore.token = '';
        userStore.roles = [];
        userStore.permissions = [];
      }).finally(() => {
        location.href = '/enterprise';
      })
    }).catch(() => {
      isRelogin.show = false;
    });
  }
}

// 使用刷新令牌换取新的访问令牌，成功后重放原请求，失败则提示重新登录
function refreshAndRetry(res) {
  const config = res.config;
  if (!refreshing) {
    refreshing = axios.post(import.meta.env.VITE_APP_BASE_API + '/auth/refresh',
      { refreshToken: getRefreshToken() },
      { timeout: 10000 }).then(response => {
        const data = response.data || {};
        if ((data.code || 200) !== 200 || !data.token) {
          return Promise.reject(new Error('刷新令牌无效或已过期'));
        }
        setToken(data.token);
        if (data.refreshToken) {
          setRefreshToken(data.refreshToken);
        }
        return data.token;
      }).finally(() => {
        refreshing = null;
      });
  }
  return refreshing.then(() => {
    // 标记该请求已重试过一次，避免二次 401 时反复刷新
    config.skipAuthRefresh = true;
    // 重复提交校验会拦截重放的相同请求，重放时跳过
    config.headers.repeatSubmit = false;
    return service(config);
  }).catch(() => {
    handleReLogin();
    return Promise.reject('无效的会话，或者会话已过期，请重新登录。');
  });
}

axios.defaults.headers['Content-Type'] = 'application/json;charset=utf-8'
// 创建axios实例
const service = axios.create({
  // axios中请求配置有baseURL选项，表示请求URL公共部分
  baseURL: import.meta.env.VITE_APP_BASE_API,
  // 超时
  timeout: 10000
})

// request拦截器
service.interceptors.request.use(config => {
  // 是否需要设置 token
  const isToken = (config.headers || {}).isToken === false
  // 是否需要防止数据重复提交
  const isRepeatSubmit = (config.headers || {}).repeatSubmit === false
  if (getToken() && !isToken) {
    config.headers['Authorization'] = 'Bearer ' + getToken() // 让每个请求携带自定义token 请根据实际情况自行修改
  }
  // get请求映射params参数
  if (config.method === 'get' && config.params) {
    let url = config.url + '?' + tansParams(config.params);
    url = url.slice(0, -1);
    config.params = {};
    config.url = url;
  }
  if (!isRepeatSubmit && (config.method === 'post' || config.method === 'put')) {
    const requestObj = {
      url: config.url,
      data: typeof config.data === 'object' ? JSON.stringify(config.data) : config.data,
      time: new Date().getTime()
    }
    const requestSize = Object.keys(JSON.stringify(requestObj)).length; // 请求数据大小
    const limitSize = 5 * 1024 * 1024; // 限制存放数据5M
    if (requestSize >= limitSize) {
      console.warn(`[${config.url}]: ` + '请求数据大小超出允许的5M限制，无法进行防重复提交验证。')
      return config;
    }
    const sessionObj = cache.session.getJSON('sessionObj')
    if (sessionObj === undefined || sessionObj === null || sessionObj === '') {
      cache.session.setJSON('sessionObj', requestObj)
    } else {
      const s_url = sessionObj.url;                // 请求地址
      const s_data = sessionObj.data;              // 请求数据
      const s_time = sessionObj.time;              // 请求时间
      const interval = 1000;                       // 间隔时间(ms)，小于此时间视为重复提交
      if (s_data === requestObj.data && requestObj.time - s_time < interval && s_url === requestObj.url) {
        const message = '数据正在处理，请勿重复提交';
        console.warn(`[${s_url}]: ` + message)
        return Promise.reject(new Error(message))
      } else {
        cache.session.setJSON('sessionObj', requestObj)
      }
    }
  }
  return config
}, error => {
    console.log(error)
    Promise.reject(error)
})

// 响应拦截器
service.interceptors.response.use(res => {
    // 未设置状态码则默认成功状态
    const code = res.data.code || 200;
    // 获取错误信息
    const msg = errorCode[code] || res.data.msg || errorCode['default']
    // 二进制数据则直接返回
    if (res.request.responseType ===  'blob' || res.request.responseType ===  'arraybuffer') {
      return res.data
    }
    if (code === 401) {
      // 本地已无访问令牌（会话已被清理或已登出）时不再提示重新登录，
      // 否则登录页上的任意 401 都会反复弹出「登录状态已过期」
      if (!getToken()) {
        return Promise.reject('无效的会话，或者会话已过期，请重新登录。')
      }
      // 持有刷新令牌且尚未重试过，则静默刷新后重放原请求
      if (!res.config.skipAuthRefresh && getRefreshToken()) {
        return refreshAndRetry(res);
      }
      handleReLogin();
      return Promise.reject('无效的会话，或者会话已过期，请重新登录。')
    } else if (code === 500) {
      ElMessage({ message: msg, type: 'error' })
      return Promise.reject(new Error(msg))
    } else if (code === 601) {
      ElMessage({ message: msg, type: 'warning' })
      return Promise.reject(new Error(msg))
    } else if (code !== 200) {
      ElNotification.error({ title: msg })
      return Promise.reject('error')
    } else {
      return  Promise.resolve(res.data)
    }
  },
  error => {
    console.log('err' + error)
    let { message } = error;
    if (message == "Network Error") {
      message = "后端接口连接异常";
    } else if (message.includes("timeout")) {
      message = "系统接口请求超时";
    } else if (message.includes("Request failed with status code")) {
      message = "系统接口" + message.substr(message.length - 3) + "异常";
    }
    ElMessage({ message: message, type: 'error', duration: 5 * 1000 })
    return Promise.reject(error)
  }
)

// 通用下载方法
export function download(url, params, filename, config) {
  downloadLoadingInstance = ElLoading.service({ text: "正在下载数据，请稍候", background: "rgba(0, 0, 0, 0.7)", })
  return service.post(url, params, {
    transformRequest: [(params) => { return tansParams(params) }],
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    responseType: 'blob',
    ...config
  }).then(async (data) => {
    const isBlob = blobValidate(data);
    if (isBlob) {
      const blob = new Blob([data])
      saveAs(blob, filename)
    } else {
      const resText = await data.text();
      const rspObj = JSON.parse(resText);
      const errMsg = errorCode[rspObj.code] || rspObj.msg || errorCode['default']
      ElMessage.error(errMsg);
    }
    downloadLoadingInstance.close();
  }).catch((r) => {
    console.error(r)
    ElMessage.error('下载文件出现错误，请联系管理员！')
    downloadLoadingInstance.close();
  })
}

export default service
