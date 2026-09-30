package com.ruoyi.framework.web.service;

import java.security.SecureRandom;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import com.ruoyi.common.constant.CacheConstants;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;

/**
 * 手机短信验证码服务。
 *
 * <p>当前项目没有接入第三方短信供应商，因此本地开发使用 Redis 保存验证码并输出到后端日志。
 * 生产环境将 mock 开关关闭后，应在此处接入实际短信发送实现。</p>
 */
@Component
public class SmsCodeService
{
    private static final Pattern PHONE_PATTERN = Pattern.compile("^1[3-9]\\d{9}$");
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int CODE_EXPIRATION_SECONDS = 300;
    private static final int SEND_COOLDOWN_SECONDS = 60;

    private final RedisCache redisCache;

    @Value("${recruit.sms.mock-enabled:false}")
    private boolean mockEnabled;

    public SmsCodeService(RedisCache redisCache)
    {
        this.redisCache = redisCache;
    }

    /**
     * 发送验证码。mock 模式下返回验证码，便于本地联调；真实短信模式返回 null。
     */
    public String sendCode(String phone, String scene)
    {
        validatePhone(phone);
        validateScene(scene);

        String normalizedPhone = phone.trim();
        if (!mockEnabled)
        {
            throw new ServiceException("短信服务尚未配置，请联系管理员");
        }

        String codeKey = getCodeKey(normalizedPhone, scene);
        String cooldownKey = getCooldownKey(normalizedPhone, scene);
        if (Boolean.TRUE.equals(redisCache.hasKey(cooldownKey)))
        {
            throw new ServiceException("验证码发送过于频繁，请稍后再试");
        }

        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        redisCache.setCacheObject(codeKey, code, CODE_EXPIRATION_SECONDS, TimeUnit.SECONDS);
        redisCache.setCacheObject(cooldownKey, "1", SEND_COOLDOWN_SECONDS, TimeUnit.SECONDS);

        System.out.println("[SMS MOCK] scene=" + scene + ", phone=" + normalizedPhone + ", code=" + code);
        return code;
    }

    /**
     * 校验并消费验证码。
     */
    public void validateCode(String phone, String scene, String code)
    {
        validatePhone(phone);
        validateScene(scene);
        if (StringUtils.isEmpty(code))
        {
            throw new ServiceException("短信验证码不能为空");
        }

        String codeKey = getCodeKey(phone.trim(), scene);
        String cachedCode = redisCache.getCacheObject(codeKey);
        redisCache.deleteObject(codeKey);
        if (StringUtils.isEmpty(cachedCode))
        {
            throw new ServiceException("短信验证码已失效，请重新获取");
        }
        if (!code.trim().equals(cachedCode))
        {
            throw new ServiceException("短信验证码错误");
        }
    }

    public void validatePhone(String phone)
    {
        if (!isValidPhone(phone))
        {
            throw new ServiceException("请输入正确的手机号");
        }
    }

    public boolean isValidPhone(String phone)
    {
        return StringUtils.isNotEmpty(phone) && PHONE_PATTERN.matcher(phone.trim()).matches();
    }

    private void validateScene(String scene)
    {
        if (!"register".equals(scene) && !"login".equals(scene))
        {
            throw new ServiceException("短信验证码场景无效");
        }
    }

    private String getCodeKey(String phone, String scene)
    {
        return CacheConstants.SMS_CODE_KEY + scene + ":" + phone;
    }

    private String getCooldownKey(String phone, String scene)
    {
        return CacheConstants.SMS_CODE_COOLDOWN_KEY + scene + ":" + phone;
    }
}
