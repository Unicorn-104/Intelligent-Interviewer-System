package com.ruoyi.system.service.biz.impl;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.mapper.biz.BizJobMapper;
import com.ruoyi.system.service.biz.IBizJobService;

/**
 * 平台运营 - 岗位监管 服务实现
 *
 * @author TQY
 */
@Service
public class BizJobServiceImpl implements IBizJobService
{
    /** 高危违规词（命中即高风险 level=2） */
    private static final String[] HIGH_RISK_WORDS = {
            "刷单", "赌博", "博彩", "配资", "代开发票", "办证", "走私", "套现", "网贷", "刷单返利"
    };
    /** 中危诱导词（命中即中风险 level=1） */
    private static final String[] MID_RISK_WORDS = {
            "急招高薪", "无经验高薪", "月入过万", "轻松月入", "保底高提成", "付费内推", "日结高薪"
    };

    @Autowired
    private BizJobMapper jobMapper;

    @Override
    public List<Map<String, Object>> selectAdminJobList(String jobName, String companyName, Integer status)
    {
        List<Map<String, Object>> rows = jobMapper.selectAdminJobList(jobName, companyName, status);
        if (rows != null)
        {
            rows.forEach(this::scanRisk);
        }
        return rows;
    }

    @Override
    public Map<String, Object> selectAdminJobById(Long posId)
    {
        Map<String, Object> job = jobMapper.selectAdminJobById(posId);
        if (job == null)
        {
            throw new ServiceException("岗位不存在");
        }
        return job;
    }

    @Override
    public int auditJob(Long posId, Integer result, String reason, Long operatorId)
    {
        if (posId == null)
        {
            throw new ServiceException("岗位不能为空");
        }
        if (result == null || (result != 1 && result != 2 && result != 3))
        {
            throw new ServiceException("审核结论非法");
        }
        Map<String, Object> exist = jobMapper.selectAdminJobById(posId);
        if (exist == null)
        {
            throw new ServiceException("岗位不存在");
        }
        // 1=通过发布，2=违规下架，3=恢复上架(下架→已发布)；先记录变更前状态，更新后写入日志
        Object current = exist.get("status");
        Integer fromStatus = current == null ? null : ((Number) current).intValue();
        // result=1 通过 / result=3 恢复 都置为已发布(1)；result=2 违规下架(2)
        int targetStatus = (result == 2) ? 2 : 1;
        int rows = jobMapper.updateJobStatus(posId, targetStatus);
        jobMapper.insertPosStatusLog(posId, fromStatus, targetStatus, reason, operatorId);
        return rows;
    }

    @Override
    public List<Map<String, Object>> selectPosStatusLogs(Long posId)
    {
        if (posId == null)
        {
            throw new ServiceException("岗位不能为空");
        }
        return jobMapper.selectPosStatusLogs(posId);
    }

    /**
     * 扫描岗位标题与 JD 文本，命中内置违规/诱导词则填充 riskLevel 与 riskWords；
     * 未命中留空，前端展示「-」。
     */
    private void scanRisk(Map<String, Object> row)
    {
        StringBuilder text = new StringBuilder();
        Object jobName = row.get("jobName");
        Object jdJson = row.get("jdJson");
        if (jobName != null)
        {
            text.append(jobName);
        }
        if (jdJson != null)
        {
            text.append(' ').append(jdJson);
        }
        String content = text.toString();

        List<String> words = new ArrayList<>();
        Integer level = null;
        for (String w : HIGH_RISK_WORDS)
        {
            if (content.contains(w) && !words.contains(w))
            {
                words.add(w);
                level = 2;
            }
        }
        if (level == null)
        {
            for (String w : MID_RISK_WORDS)
            {
                if (content.contains(w) && !words.contains(w))
                {
                    words.add(w);
                    level = 1;
                }
            }
        }
        row.put("riskLevel", level);
        row.put("riskWords", words);
        // 列表无需返回大段 JD 原文
        row.remove("jdJson");
    }
}
