package com.ruoyi.system.service;

/**
 * 短信发送网关接口。
 *
 * <p>当前项目未接入第三方短信供应商，默认使用 {@code UnconfiguredSmsGateway} 兜底。
 * 生产接入时在实现类（如阿里云/腾讯云短信）上标注 {@code @Primary} 注册为 Bean 即可，
 * 业务侧无需改动。</p>
 */
public interface SmsGateway
{
    /**
     * 向指定手机号发送短信文本。
     *
     * @param phone   已校验的 11 位手机号
     * @param content 短信正文（含签名与模板内容由实现方决定）
     */
    void send(String phone, String content);
}
