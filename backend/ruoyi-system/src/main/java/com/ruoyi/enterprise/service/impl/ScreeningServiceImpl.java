package com.ruoyi.enterprise.service.impl;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.mapper.ScreeningMapper;
import com.ruoyi.enterprise.service.IScreeningService;
import com.ruoyi.system.mapper.DashboardMapper;

/**
 * 企业端 - AI 初筛与智能匹配服务实现
 *
 * <p>依据《业务功能分析》：</p>
 * <ul>
 *   <li>UC-04：硬性条件过滤（必备技能标签比对，学历/年限等刚性门槛待解析口径对齐后接入）</li>
 *   <li>UC-05 步骤3-4：多维度加权评分——技能标签重合度 30%、项目经验相关性 30%、
 *       教育背景匹配度 20%、行业/领域经验匹配 20%；其中技能维度基于岗位技能标签与
 *       候选人技能标签的真实重合度计算，其余三个语义维度依赖向量匹配服务，
 *       接入前以基准分占位（P7 待替换）</li>
 *   <li>UC-05 步骤5：按综合评分降序截取 Top N 短名单</li>
 *   <li>UC-05 步骤6-8：推荐报告与招呼语读取 t_greeting_record（grt_match_points JSON
 *       承载匹配点/风险点/待核实点，grt_content 为招呼语文案）</li>
 *   <li>UC-06：HR 复核确认后候选人状态推进为"初筛通过"（tal_status=1，
 *       状态变更由数据库触发器自动写入 t_tal_status_log）</li>
 * </ul>
 *
 * @author enterprise
 */
@Service
public class ScreeningServiceImpl implements IScreeningService
{
    /** 各维度权重（UC-05 步骤3）：技能 30% / 项目 30% / 教育 20% / 行业 20% */
    private static final double SKILL_WEIGHT = 0.30;
    private static final double PROJECT_WEIGHT = 0.30;
    private static final double EDUCATION_WEIGHT = 0.20;
    private static final double INDUSTRY_WEIGHT = 0.20;

    /** 语义维度占位基准分（项目/教育/行业依赖向量匹配服务，P7 接入后替换） */
    private static final double BASE_SEMANTIC_SCORE = 70.0;

    @Autowired
    private ScreeningMapper screeningMapper;

    @Autowired
    private DashboardMapper dashboardMapper;

    @Override
    public Map<String, Object> triggerScreening(Long userId, Long positionId, Integer topN)
    {
        if (positionId == null)
        {
            throw new ServiceException("岗位ID不能为空");
        }
        // 岗位必备技能标签（UC-01 硬性指标，作为 UC-04 硬性过滤依据）
        List<String> requiredSkills = screeningMapper.selectPositionSkills(positionId);
        if (requiredSkills.isEmpty())
        {
            throw new ServiceException("该岗位尚未生成技能标签画像，请先在岗位详情解析 JD");
        }
        // 该岗位的候选人池（来自流程实例）
        List<Map<String, Object>> candidates = screeningMapper.selectCandidatesByPosition(positionId);

        int passedCount = 0;
        for (Map<String, Object> candidate : candidates)
        {
            Long talId = Long.valueOf(String.valueOf(candidate.get("talentId")));
            List<String> candidateSkills = screeningMapper.selectCandidateSkills(talId);
            // UC-05 步骤3：技能标签重合度
            double skillScore = computeOverlapScore(requiredSkills, candidateSkills);
            boolean hardPass = skillScore > 0;
            if (!hardPass)
            {
                // UC-04：硬性过滤淘汰（无任何必备技能重合），保持状态不变，等待后续口径扩展
                continue;
            }
            passedCount++;
            // UC-05 步骤4：加权汇总（技能真实计算，其余语义维度占位基准分）
            double total = skillScore * SKILL_WEIGHT
                    + BASE_SEMANTIC_SCORE * PROJECT_WEIGHT
                    + BASE_SEMANTIC_SCORE * EDUCATION_WEIGHT
                    + BASE_SEMANTIC_SCORE * INDUSTRY_WEIGHT;
            screeningMapper.updateMatchedScore(talId, round(total));
        }
        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("taskId", positionId);
        summary.put("candidateCount", candidates.size());
        summary.put("passedCount", passedCount);
        summary.put("topN", topN == null ? 20 : topN);
        return summary;
    }

    @Override
    public List<Map<String, Object>> listTasks(Long userId, Integer pageNum, Integer pageSize)
    {
        PageUtils.startPage(pageNum, pageSize);
        return screeningMapper.selectTaskList();
    }

    @Override
    public List<Map<String, Object>> listResults(Long userId, Long taskId)
    {
        List<String> requiredSkills = screeningMapper.selectPositionSkills(taskId);
        List<Map<String, Object>> candidates = screeningMapper.selectResultsByPosition(taskId);
        for (Map<String, Object> candidate : candidates)
        {
            fillDimensions(candidate, requiredSkills);
        }
        return candidates;
    }

    @Override
    public List<Map<String, Object>> listShortlist(Long userId, Long taskId, Integer topN)
    {
        List<Map<String, Object>> results = listResults(userId, taskId);
        int limit = topN == null ? results.size() : Math.min(topN, results.size());
        return results.subList(0, limit);
    }

    @Override
    public Map<String, Object> getReport(Long userId, Long resultId)
    {
        Map<String, Object> record = screeningMapper.selectGreetingByCandidate(resultId);
        if (record == null)
        {
            throw new ServiceException("该候选人暂无 AI 推荐报告（未触发深度分析或未生成）");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        // grt_match_points JSON 承载匹配点/风险点/待核实点（UC-05 步骤6-7）
        result.put("matchPoints", record.get("matchPoints") == null ? null
                : JSON.parse(String.valueOf(record.get("matchPoints"))));
        result.put("content", record.get("content"));
        result.put("status", record.get("status"));
        result.put("sentAt", record.get("sentAt"));
        return result;
    }

    @Override
    public Map<String, Object> getGreeting(Long userId, Long resultId)
    {
        Map<String, Object> record = screeningMapper.selectGreetingByCandidate(resultId);
        if (record == null)
        {
            throw new ServiceException("该候选人暂无个性化招呼语（Top 3 才自动生成）");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("content", record.get("content"));
        result.put("status", record.get("status"));
        result.put("sentAt", record.get("sentAt"));
        return result;
    }

    @Override
    public Map<String, Object> reviewResult(Long userId, Long resultId, Boolean approved, Double adjustScore)
    {
        if (approved == null)
        {
            throw new ServiceException("复核结论不能为空");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("resultId", resultId);
        result.put("approved", approved);
        if (Boolean.TRUE.equals(approved))
        {
            if (adjustScore != null)
            {
                screeningMapper.updateMatchedScore(resultId, round(adjustScore));
                result.put("adjustScore", round(adjustScore));
            }
            // UC-06：确认通过 → 状态推进为"初筛通过"（tal_status=1），
            // 状态变更日志由数据库触发器 trg_tal_status_log_after_update 自动写入
            int updated = screeningMapper.updateTalStatus(resultId, 1);
            if (updated == 0)
            {
                throw new ServiceException("候选人不存在");
            }
            result.put("message", "已确认通过，候选人状态推进为初筛通过，等待流入面试邀约");
        }
        else
        {
            result.put("message", "已驳回，候选人保持在人才库待观察");
        }
        return result;
    }

    /** 维度明细填充：技能维度真实计算，其余语义维度占位（P7 对接向量服务后替换） */
    private void fillDimensions(Map<String, Object> candidate, List<String> requiredSkills)
    {
        List<String> candidateSkills = new ArrayList<>();
        Object skillsRaw = candidate.get("skills");
        if (skillsRaw != null && !String.valueOf(skillsRaw).isEmpty())
        {
            for (String skill : String.valueOf(skillsRaw).split(","))
            {
                candidateSkills.add(skill.trim());
            }
        }
        double skillScore = computeOverlapScore(requiredSkills, candidateSkills);
        candidate.put("skillMatch", round(skillScore));
        candidate.put("projectMatch", null);
        candidate.put("educationMatch", null);
        candidate.put("industryMatch", null);
    }

    /** 技能重合度：候选人技能 ∩ 岗位必备技能 / 岗位必备技能数 * 100（UC-05 技能维度） */
    private double computeOverlapScore(List<String> requiredSkills, List<String> candidateSkills)
    {
        if (requiredSkills.isEmpty())
        {
            return 0;
        }
        int overlap = 0;
        for (String required : requiredSkills)
        {
            for (String skill : candidateSkills)
            {
                if (required.equalsIgnoreCase(skill))
                {
                    overlap++;
                    break;
                }
            }
        }
        return overlap * 100.0 / requiredSkills.size();
    }

    private double round(double value)
    {
        return BigDecimal.valueOf(value).setScale(1, RoundingMode.HALF_UP).doubleValue();
    }

    @SuppressWarnings("unused")
    private Long resolveCompanyId(Long userId)
    {
        Long companyId = dashboardMapper.selectCompanyIdByUser(userId);
        return companyId == null ? 1L : companyId;
    }
}
