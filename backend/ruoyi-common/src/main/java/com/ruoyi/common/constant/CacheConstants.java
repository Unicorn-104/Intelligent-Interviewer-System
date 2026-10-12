package com.ruoyi.common.constant;

/**
 * 缓存的key 常量
 * 
 * @author ruoyi
 */
public class CacheConstants
{
    /**
     * 登录用户 redis key
     */
    public static final String LOGIN_TOKEN_KEY = "login_tokens:";

    /**
     * 验证码 redis key
     */
    public static final String CAPTCHA_CODE_KEY = "captcha_codes:";

    /**
     * 手机短信验证码 redis key
     */
    public static final String SMS_CODE_KEY = "sms_codes:";

    /**
     * 手机短信验证码发送冷却 redis key
     */
    public static final String SMS_CODE_COOLDOWN_KEY = "sms_code_cooldown:";

    /**
     * 参数管理 cache key
     */
    public static final String SYS_CONFIG_KEY = "sys_config:";

    /**
     * 字典管理 cache key
     */
    public static final String SYS_DICT_KEY = "sys_dict:";

    /**
     * 防重提交 redis key
     */
    public static final String REPEAT_SUBMIT_KEY = "repeat_submit:";

    /**
     * 限流 redis key
     */
    public static final String RATE_LIMIT_KEY = "rate_limit:";

    /**
     * 登录账户密码错误次数 redis key
     */
    public static final String PWD_ERR_CNT_KEY = "pwd_err_cnt:";

    /**
     * 刷新令牌 redis key，refresh:{jti} -> userId:sessionId，一次性使用
     */
    public static final String REFRESH_TOKEN_KEY = "refresh:";

    /**
     * 用户刷新令牌索引 redis key，user_refresh:{userId} -> Set<jti>
     */
    public static final String USER_REFRESH_KEY = "user_refresh:";

    /**
     * 访问令牌黑名单 redis key，blacklist:access:{jti} -> 1
     */
    public static final String ACCESS_BLACKLIST_KEY = "blacklist:access:";

    /**
     * 令牌版本号 redis key，user_token_ver:{userId} -> number
     */
    public static final String TOKEN_VERSION_KEY = "user_token_ver:";
}
