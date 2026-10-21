package com.ruoyi.system.config;

import jakarta.annotation.PostConstruct;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 实时语音识别配置。
 *
 * 通过 app.asr.provider 切换实现，密钥只允许放在本地私有配置或环境变量中。
 */
@Configuration
@ConfigurationProperties(prefix = "app.asr")
public class AsrProperties
{
    private static final Logger log = LoggerFactory.getLogger(AsrProperties.class);

    /** 是否启用实时字幕 */
    private boolean enabled = true;

    /** 识别服务提供方，当前支持 tencent */
    private String provider = "tencent";

    /** 字幕不可用时的兜底提示 */
    private String degradeMessage = "字幕服务未启用";

    private Tencent tencent = new Tencent();

    /**
     * 启动时输出配置是否就绪，便于定位「配置文件未加载」类问题（不输出密钥内容）。
     */
    @PostConstruct
    public void logConfiguration()
    {
        log.info("实时字幕配置：{}", isReady() ? "腾讯云已就绪" : getUnavailableReason());
    }

    public boolean isReady()
    {
        if (!enabled)
        {
            return false;
        }
        if (!"tencent".equalsIgnoreCase(provider))
        {
            return false;
        }
        return StringUtils.isNotBlank(tencent.getAppId())
                && StringUtils.isNotBlank(tencent.getSecretId())
                && StringUtils.isNotBlank(tencent.getSecretKey());
    }

    /**
     * 返回当前不可用的具体原因，便于前端明确标注降级状态。
     */
    public String getUnavailableReason()
    {
        if (!enabled)
        {
            return "字幕服务已关闭";
        }
        if (!"tencent".equalsIgnoreCase(provider))
        {
            return "字幕服务提供方未配置";
        }
        if (StringUtils.isBlank(tencent.getSecretId()))
        {
            return "字幕服务未配置（缺少 SecretId）";
        }
        if (StringUtils.isBlank(tencent.getSecretKey()))
        {
            return "字幕服务未配置（缺少 SecretKey）";
        }
        if (StringUtils.isBlank(tencent.getAppId()))
        {
            return "字幕服务未配置（缺少 AppID）";
        }
        return StringUtils.isNotBlank(degradeMessage) ? degradeMessage : "字幕服务未启用";
    }

    public boolean isEnabled()
    {
        return enabled;
    }

    public void setEnabled(boolean enabled)
    {
        this.enabled = enabled;
    }

    public String getProvider()
    {
        return provider;
    }

    public void setProvider(String provider)
    {
        this.provider = provider;
    }

    public String getDegradeMessage()
    {
        return degradeMessage;
    }

    public void setDegradeMessage(String degradeMessage)
    {
        this.degradeMessage = degradeMessage;
    }

    public Tencent getTencent()
    {
        return tencent;
    }

    public void setTencent(Tencent tencent)
    {
        this.tencent = tencent;
    }

    public static class Tencent
    {
        /** 腾讯云 AppID，实时语音识别 WebSocket 地址必填 */
        private String appId;

        /** 腾讯云 SecretId */
        private String secretId;

        /** 腾讯云 SecretKey */
        private String secretKey;

        /** 引擎模型，16k_zh 表示中文普通话 16k 采样 */
        private String engineModelType = "16k_zh";

        /** WebSocket 基础地址，便于后续替换服务地址 */
        private String wsBaseUrl = "wss://asr.cloud.tencent.com/asr/v2";

        /** 签名有效期（秒） */
        private int expireSeconds = 300;

        /** VAD 静音断句时间（毫秒） */
        private int vadSilenceTime = 1000;

        public String getAppId()
        {
            return appId;
        }

        public void setAppId(String appId)
        {
            this.appId = appId;
        }

        public String getSecretId()
        {
            return secretId;
        }

        public void setSecretId(String secretId)
        {
            this.secretId = secretId;
        }

        public String getSecretKey()
        {
            return secretKey;
        }

        public void setSecretKey(String secretKey)
        {
            this.secretKey = secretKey;
        }

        public String getEngineModelType()
        {
            return engineModelType;
        }

        public void setEngineModelType(String engineModelType)
        {
            this.engineModelType = engineModelType;
        }

        public String getWsBaseUrl()
        {
            return wsBaseUrl;
        }

        public void setWsBaseUrl(String wsBaseUrl)
        {
            this.wsBaseUrl = wsBaseUrl;
        }

        public int getExpireSeconds()
        {
            return expireSeconds;
        }

        public void setExpireSeconds(int expireSeconds)
        {
            this.expireSeconds = expireSeconds;
        }

        public int getVadSilenceTime()
        {
            return vadSilenceTime;
        }

        public void setVadSilenceTime(int vadSilenceTime)
        {
            this.vadSilenceTime = vadSilenceTime;
        }
    }
}
