package com.ruoyi.enterprise.service;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.sql.Timestamp;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.ruoyi.enterprise.mapper.EnterpriseSystemNoticeMapper;
import com.ruoyi.system.mapper.DashboardMapper;

/** 根据已提交的真实业务记录补齐站内通知；不修改面试、投递或报告。 */
@Service
public class EnterpriseSystemNoticeService
{
    @Autowired private EnterpriseSystemNoticeMapper mapper;
    @Autowired private DashboardMapper companies;

    @Transactional(rollbackFor=Exception.class)
    public void refresh(Long userId)
    {
        if(userId==null || userId<=0 || mapper.lockRecipient(userId)==null) return;
        Long company=companies.selectCompanyIdByUser(userId);
        if(company==null || company<=0) return;
        LocalDateTime now=LocalDateTime.now(ZoneOffset.ofHours(8));
        LocalDateTime since=now.minusDays(7);
        for(var row:mapper.applications(userId,company,since))
            save(userId,3,"收到新的简历投递",row,"已向该岗位投递简历，请前往岗位候选人列表查看。");
        for(var row:mapper.upcoming(userId,company,now,now.plusMinutes(60)))
        {
            Object value=row.get("startTime");
            LocalDateTime start=value instanceof Timestamp ? ((Timestamp)value).toLocalDateTime() :
                    value instanceof LocalDateTime ? (LocalDateTime)value : LocalDateTime.parse(String.valueOf(value).replace(' ','T'));
            save(userId,1,"面试即将开始",row,"面试将于"+start.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"))+"开始，请提前做好准备。");
        }
        for(var row:mapper.interviewStates(userId,company,since))
            save(userId,1,String.valueOf(row.get("title")),row,"面试状态已更新，请核对最新日程安排。");
        for(var row:mapper.reports(userId,company,since))
            save(userId,2,"面试报告已生成",row,"面试报告已生成，请前往面试复核页面查看。");
    }

    private void save(Long userId,int type,String title,Map<String,Object> row,String body)
    {
        String candidate=row.get("candidateName")==null?"求职者":String.valueOf(row.get("candidateName"));
        String position=row.get("positionName")==null?"面试岗位":String.valueOf(row.get("positionName"));
        mapper.insertNotice(userId,type,title,"候选人："+candidate+"\n岗位："+position+"\n"+body,String.valueOf(row.get("target")));
    }
}
