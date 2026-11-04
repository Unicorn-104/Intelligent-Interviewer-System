package com.ruoyi.system.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.CredentialCipher;
import com.ruoyi.system.domain.IntegrationSecret;
import com.ruoyi.system.mapper.IntegrationSecretMapper;

/**
 * 第三方集成凭据读取：数据库优先，缺失或不可用时回退到配置文件。
 *
 * <p>启动时把历史明文值加密为 {@code ENC:} 密文，便于部署阶段直接执行 SQL 导入。</p>
 */
@Service
public class IntegrationSecretService implements ApplicationRunner
{
    private static final Logger log = LoggerFactory.getLogger(IntegrationSecretService.class);

    private final IntegrationSecretMapper mapper;

    @Value("${app.secret.crypto-key:Intelligent-Interviewer-Secret@2026}")
    private String cryptoKey;

    public IntegrationSecretService(IntegrationSecretMapper mapper)
    {
        this.mapper = mapper;
    }

    public String get(String scope, String key)
    {
        return get(scope, key, "");
    }

    /**
     * 读取并解密配置值；行不存在、已禁用、空白或解密失败时返回 fallback。
     */
    public String get(String scope, String key, String fallback)
    {
        try
        {
            IntegrationSecret row = mapper.selectByScopeAndKey(scope, key);
            if (row == null || row.getStatus() == null || row.getStatus() != 1)
            {
                return fallback;
            }
            String plain = CredentialCipher.decrypt(row.getValue(), cryptoKey);
            return plain == null || plain.isBlank() ? fallback : plain;
        }
        catch (RuntimeException error)
        {
            // 不输出凭据内容，只提示回退原因
            log.warn("集成凭据 {}.{} 读取失败，使用配置文件兜底：{}", scope, key, error.getMessage());
            return fallback;
        }
    }

    @Override
    public void run(ApplicationArguments args)
    {
        try
        {
            for (IntegrationSecret row : mapper.selectAll())
            {
                String value = row.getValue();
                if (value == null || value.isBlank() || CredentialCipher.isEncrypted(value))
                {
                    continue;
                }
                mapper.updateValueById(row.getId(), CredentialCipher.encrypt(value, cryptoKey));
                log.info("集成凭据 {}.{} 已加密落库", row.getScope(), row.getKey());
            }
        }
        catch (Throwable error)
        {
            log.warn("集成凭据表不可用，继续使用配置文件中的兜底配置：{}", error.getMessage());
        }
    }
}
