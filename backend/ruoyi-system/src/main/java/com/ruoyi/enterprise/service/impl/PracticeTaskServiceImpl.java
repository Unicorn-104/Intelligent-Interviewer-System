package com.ruoyi.enterprise.service.impl;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.PracticeTaskMapper;
import com.ruoyi.enterprise.service.IPracticeTaskService;

/**
 * 企业端 - 在线实操环境预加载服务实现
 *
 * <p>依据《业务功能分析》UC-11：
 * 技术类岗位且面试模式包含实操环节的场次，在准备阶段异步预加载
 * 代码沙箱/云端 IDE。当前实现为同步"就绪校验"（模拟即时就绪），
 * 真实异步初始化待 P7 对接沙箱服务后替换。</p>
 *
 * @author enterprise
 */
@Service
public class PracticeTaskServiceImpl implements IPracticeTaskService
{
    @Autowired
    private PracticeTaskMapper practiceTaskMapper;

    @Override
    public Map<String, Object> preload(Long userId, Long sessionId)
    {
        Map<String, Object> session = practiceTaskMapper.selectSessionBase(sessionId);
        if (session == null)
        {
            throw new ServiceException("面试场次不存在");
        }
        // UC-11：按场次模板/岗位拉取实操考题，全部就绪即视为环境可用（模拟）
        List<Map<String, Object>> tasks = practiceTaskMapper.selectTasks(sessionId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("taskCount", tasks.size());
        result.put("status", tasks.isEmpty() ? "no_practice" : "ready");
        result.put("message", tasks.isEmpty()
                ? "该场次无实操考核环节，无需预加载"
                : "实操环境已就绪（模拟），候选人进入面试后无需等待初始化");
        return result;
    }

    @Override
    public Map<String, Object> status(Long userId, Long sessionId)
    {
        Map<String, Object> session = practiceTaskMapper.selectSessionBase(sessionId);
        if (session == null)
        {
            throw new ServiceException("面试场次不存在");
        }
        List<Map<String, Object>> tasks = practiceTaskMapper.selectTasks(sessionId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("sessionId", sessionId);
        result.put("positionTitle", session.get("positionTitle"));
        result.put("hasPractice", !tasks.isEmpty());
        result.put("status", tasks.isEmpty() ? "no_practice" : "ready");
        result.put("tasks", tasks);
        return result;
    }
}
