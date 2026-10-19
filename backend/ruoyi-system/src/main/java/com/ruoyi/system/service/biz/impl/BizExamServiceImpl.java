package com.ruoyi.system.service.biz.impl;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.system.mapper.biz.BizExamMapper;
import com.ruoyi.system.service.biz.IBizExamService;

/**
 * 平台运营 - 考核环境配置与记录 服务实现（配置降级）
 *
 * @author TQY
 */
@Service
public class BizExamServiceImpl implements IBizExamService
{
    @Autowired
    private BizExamMapper examMapper;

    @Override
    public Map<String, Object> getConfig()
    {
        // 降级：无独立考核配置表，返回前端默认值
        Map<String, Object> config = new java.util.LinkedHashMap<>();
        config.put("languages", List.of("Java", "Python", "JavaScript", "C++", "Go", "SQL"));
        config.put("editorTheme", "vs-dark");
        config.put("timeLimit", 60);
        config.put("memoryLimit", 256);
        config.put("autoSubmit", true);
        config.put("plagiarismCheck", false);
        config.put("status", "0");
        config.put("remark", null);
        return config;
    }

    @Override
    public void saveConfig(Map<String, Object> body)
    {
        // 降级：无配置表，暂不持久化
    }

    @Override
    public List<Map<String, Object>> listRecords()
    {
        List<Map<String, Object>> all = examMapper.selectAdminExamRecords();
        return all.size() > 10 ? all.subList(0, 10) : all;
    }
}
