package com.ruoyi.common.core.domain.model;

/**
 * 手机短信验证码请求对象。
 */
public class SmsCodeBody
{
    private String phone;

    /**
     * 验证码场景：register、login。
     */
    private String scene;

    public String getPhone()
    {
        return phone;
    }

    public void setPhone(String phone)
    {
        this.phone = phone;
    }

    public String getScene()
    {
        return scene;
    }

    public void setScene(String scene)
    {
        this.scene = scene;
    }
}
