package com.ruoyi.system.service.app.pdf;

/** 解析策略入口，供后续新增解析器与管理员配置使用。 */
public interface ResumePdfParser
{
    record Result(String text, String method) { }
    Result parse(byte[] bytes);
    void validate(byte[] bytes);
}
