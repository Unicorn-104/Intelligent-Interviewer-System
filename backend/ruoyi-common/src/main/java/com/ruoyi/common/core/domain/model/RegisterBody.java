package com.ruoyi.common.core.domain.model;

/**
 * 用户注册对象
 * 
 * @author ruoyi
 */
public class RegisterBody extends LoginBody
{
    /**
     * 注册方式：phone、account_password
     */
    private String registerType;

    public String getRegisterType()
    {
        return registerType;
    }

    public void setRegisterType(String registerType)
    {
        this.registerType = registerType;
    }
}
