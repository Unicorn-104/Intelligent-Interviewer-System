import router from '@/router'
import cache from '@/plugins/cache'
import { ElMessageBox, } from 'element-plus'
import { login, loginByAccountPassword, loginBySms, logout, getInfo } from '@/api/login'
import { getToken, setToken, removeToken } from '@/utils/auth'
import { isHttp, isEmpty } from "@/utils/validate"
import useLockStore from '@/store/modules/lock'
import defAva from '@/assets/images/profile.jpg'
import { hasCandidateSecurityNoticeShown, markCandidateSecurityNoticeShown } from '@/utils/agentSession'

const useUserStore = defineStore(
  'user',
  {
    state: () => ({
      token: getToken(),
      id: '',
      name: '',
      nickName: '',
      avatar: '',
      roles: [],
      permissions: [],
      userIdentityType: null
    }),
    actions: {
      // 登录
      login(userInfo) {
        const phone = (userInfo.phone || '').trim()
        const account = (userInfo.account || userInfo.username || '').trim()
        const password = userInfo.password
        const code = userInfo.code
        const uuid = userInfo.uuid
        const loginRequest = userInfo.loginType === 'sms'
          ? loginBySms(phone, userInfo.smsCode)
          : userInfo.loginType === 'account_password'
              ? loginByAccountPassword(account, password)
            : login(userInfo.username.trim(), password, code, uuid)
        return new Promise((resolve, reject) => {
          loginRequest.then(res => {
            setToken(res.token)
            this.token = res.token
            useLockStore().unlockScreen()
            resolve()
          }).catch(error => {
            reject(error)
          })
        })
      },
      // 获取用户信息
      getInfo() {
        return new Promise((resolve, reject) => {
          getInfo().then(res => {
            const user = res.user
            let avatar = user.avatar || ""
            if (!isHttp(avatar)) {
              avatar = (isEmpty(avatar)) ? defAva : import.meta.env.VITE_APP_BASE_API + avatar
            }
            if (res.roles && res.roles.length > 0) { // 验证返回的roles是否是一个非空数组
              this.roles = res.roles
              this.permissions = res.permissions
            } else {
              this.roles = ['ROLE_DEFAULT']
            }
            this.id = user.userId
            this.userIdentityType = user.userIdentityType
            this.name = user.userName
            this.nickName = user.nickName
            this.avatar = avatar
            cache.session.set('pwrChrtype', res.pwdChrtype)
            const showDefaultPasswordNotice = Boolean(res.isDefaultModifyPwd)
            const showExpiredPasswordNotice = !showDefaultPasswordNotice && Boolean(res.isPasswordExpired)
            if (!hasCandidateSecurityNoticeShown() && (showDefaultPasswordNotice || showExpiredPasswordNotice)) {
              markCandidateSecurityNoticeShown()
              const message = showDefaultPasswordNotice
                ? '您的密码还是初始密码，请修改密码！'
                : '您的密码已过期，请尽快修改密码！'
              ElMessageBox.confirm(message, '安全提示', { confirmButtonText: '确定', cancelButtonText: '取消', type: 'warning' }).then(() => {
                router.push({ name: 'Profile', params: { activeTab: 'resetPwd' } })
              }).catch(() => {})
            }
            resolve(res)
          }).catch(error => {
            reject(error)
          })
        })
      },
      // 退出系统
      logOut() {
        return new Promise((resolve, reject) => {
          logout(this.token).then(() => {
            this.token = ''
            this.roles = []
            this.permissions = []
            this.userIdentityType = null
            removeToken()
            resolve()
          }).catch(error => {
            reject(error)
          })
        })
      }
    }
  })

export default useUserStore
