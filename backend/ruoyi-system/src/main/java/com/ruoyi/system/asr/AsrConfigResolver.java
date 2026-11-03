package com.ruoyi.system.asr;

import org.springframework.stereotype.Component;
import com.ruoyi.system.config.AsrProperties;
import com.ruoyi.system.service.IntegrationSecretService;

/**
 * ASR 配置解析：密钥优先取数据库加密凭据，缺失时回退到配置文件。
 */
@Component
public class AsrConfigResolver
{
    private static final String SCOPE = "asr";

    public static final String KEY_APP_ID = "app-id";

    public static final String KEY_SECRET_ID = "secret-id";

    public static final String KEY_SECRET_KEY = "secret-key";

    private final AsrProperties properties;

    private final IntegrationSecretService secrets;

    public AsrConfigResolver(AsrProperties properties, IntegrationSecretService secrets)
    {
        this.properties = properties;
        this.secrets = secrets;
    }

    public String provider()
    {
        return properties.getProvider();
    }

    public boolean isEnabled()
    {
        return properties.isEnabled();
    }

    public boolean isReady()
    {
        return resolved().isReady();
    }

    public String unavailableReason()
    {
        return resolved().getUnavailableReason();
    }

    public AsrProperties.Tencent tencent()
    {
        AsrProperties.Tencent source = properties.getTencent();
        AsrProperties.Tencent resolved = new AsrProperties.Tencent();
        resolved.setAppId(secrets.get(SCOPE, KEY_APP_ID, source.getAppId()));
        resolved.setSecretId(secrets.get(SCOPE, KEY_SECRET_ID, source.getSecretId()));
        resolved.setSecretKey(secrets.get(SCOPE, KEY_SECRET_KEY, source.getSecretKey()));
        resolved.setEngineModelType(source.getEngineModelType());
        resolved.setWsBaseUrl(source.getWsBaseUrl());
        resolved.setExpireSeconds(source.getExpireSeconds());
        resolved.setVadSilenceTime(source.getVadSilenceTime());
        return resolved;
    }

    /** 用合并后的配置复用 AsrProperties 的校验与降级提示逻辑 */
    private AsrProperties resolved()
    {
        AsrProperties snapshot = new AsrProperties();
        snapshot.setEnabled(properties.isEnabled());
        snapshot.setProvider(properties.getProvider());
        snapshot.setDegradeMessage(properties.getDegradeMessage());
        snapshot.setTencent(tencent());
        return snapshot;
    }
}
