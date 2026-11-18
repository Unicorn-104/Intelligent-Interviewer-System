package com.ruoyi.enterprise.service.impl;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.ruoyi.common.enums.ApplicationStatus;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.ProcessStageInstance;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.service.ISendCenterService;
import com.ruoyi.enterprise.service.ProcessStageInstanceService;
import com.ruoyi.system.mapper.ConferenceMapper;
import com.ruoyi.system.mapper.DashboardMapper;

/**
 * 笔试与面试发送中心：发送前的上下文聚合查询
 *
 * @author ruoyi
 */
@Service
public class SendCenterServiceImpl implements ISendCenterService
{
    @Autowired
    private ConferenceMapper conferenceMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Autowired
    private ApplicationStatusMapper applicationStatusMapper;

    @Autowired
    private ProcessStageInstanceService processStageInstanceService;

    @Override
    public Map<String, Object> getContext(Long userId, Long candidateId, Long positionId)
    {
        if (candidateId == null || positionId == null)
        {
            throw new ServiceException("请选择候选人与投递岗位");
        }
        Long companyId = resolveCompanyId(userId);
        Long ownerCompanyId = conferenceMapper.selectPositionCompanyId(positionId);
        if (ownerCompanyId == null || !ownerCompanyId.equals(companyId))
        {
            throw new ServiceException("岗位不存在或无权访问");
        }
        Long appId = applicationStatusMapper.selectAppId(candidateId, positionId);
        if (appId == null)
        {
            throw new ServiceException("该候选人未投递当前岗位");
        }
        Map<String, Object> application = applicationStatusMapper.selectApplicationById(appId);
        Integer appStatus = application == null ? null : asInt(application.get("status"));
        Long instanceId = application == null ? null : asLong(application.get("instanceId"));

        Map<String, Object> stageParams = new HashMap<>();
        stageParams.put("positionId", positionId);
        stageParams.put("companyId", companyId);
        List<Map<String, Object>> stages = conferenceMapper.selectStagesByPosition(stageParams);

        Set<Long> passedStageIds = new LinkedHashSet<>();
        boolean examPassed = false;
        if (instanceId != null)
        {
            for (ProcessStageInstance node : processStageInstanceService.listNodes(instanceId))
            {
                if (node.getResult() == null || node.getResult() != ProcessStageInstance.RESULT_PASS)
                {
                    continue;
                }
                if (node.getStageId() != null)
                {
                    passedStageIds.add(node.getStageId());
                }
                if (node.getNodeType() != null && node.getNodeType() == ProcessStageInstance.TYPE_EXAM)
                {
                    examPassed = true;
                }
            }
        }

        List<Map<String, Object>> stageViews = new ArrayList<>();
        for (Map<String, Object> stage : stages)
        {
            Map<String, Object> view = new LinkedHashMap<>(stage);
            Long stageId = asLong(stage.get("stageId"));
            view.put("passed", stageId != null && passedStageIds.contains(stageId));
            stageViews.add(view);
        }

        ApplicationStatus status = appStatus == null ? null : ApplicationStatus.fromCode(appStatus);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("applicationId", appId);
        result.put("candidateId", candidateId);
        result.put("positionId", positionId);
        result.put("appStatus", appStatus);
        result.put("appStatusLabel", status == null ? "—" : status.getLabel());
        result.put("terminal", status != null && status.isTerminal());
        result.put("instanceId", instanceId);
        result.put("examPassed", examPassed);
        result.put("passedStageIds", new ArrayList<>(passedStageIds));
        result.put("stages", stageViews);
        result.put("activeAppointment", conferenceMapper.selectActiveAppointment(candidateId, positionId, companyId));
        return result;
    }

    /** 当前登录用户所属企业，缺失时沿用系统默认企业口径 */
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }

    private static Long asLong(Object value)
    {
        if (value == null)
        {
            return null;
        }
        if (value instanceof Number)
        {
            return ((Number) value).longValue();
        }
        String text = String.valueOf(value).trim();
        return text.isEmpty() ? null : Long.valueOf(text);
    }

    private static Integer asInt(Object value)
    {
        Long number = asLong(value);
        return number == null ? null : number.intValue();
    }
}
