package com.ruoyi.system.service.biz.impl;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.biz.BizInterviewMapper;
import com.ruoyi.system.service.biz.IBizInterviewService;

/**
 * 平台运营 - 面试会话监管 服务实现
 *
 * @author TQY
 */
@Service
public class BizInterviewServiceImpl implements IBizInterviewService
{
    @Autowired
    private BizInterviewMapper interviewMapper;

    @Override
    public List<Map<String, Object>> selectAdminInterviewList()
    {
        return interviewMapper.selectAdminInterviewList();
    }

    @Override
    public Map<String, Object> selectAdminInterviewById(Long sesId)
    {
        Map<String, Object> session = interviewMapper.selectAdminInterviewById(sesId);
        if (session == null)
        {
            throw new ServiceException("面试会话不存在");
        }
        session.put("authLogs", List.of());
        return session;
    }

    @Override
    public int terminateInterview(Long sesId, String reason)
    {
        if (sesId == null)
        {
            throw new ServiceException("面试会话不能为空");
        }
        if (interviewMapper.selectAdminInterviewById(sesId) == null)
        {
            throw new ServiceException("面试会话不存在");
        }
        // 降级：reason 无列不持久化；仅进行中(1)可被强制结束
        return interviewMapper.terminateInterview(sesId);
    }
}
