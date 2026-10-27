package com.ruoyi.enterprise.service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.EnterpriseSystemNoticeMapper;
import com.ruoyi.system.mapper.DashboardMapper;

/** 只从当前接收人的通知解析业务ID，并重新校验当前企业归属。 */
@Service
public class EnterpriseNoticeDestinationService
{
    private static final Pattern TARGET=Pattern.compile("^/enterprise/system-events/(applications|reports|interviews)/([1-9][0-9]*)(?:/(status/[0123]|upcoming/[0-9]{12}))?$");
    @Autowired private EnterpriseSystemNoticeMapper mapper;
    @Autowired private DashboardMapper companies;

    public Map<String,Object> resolve(Long userId,Long messageId)
    {
        if(messageId==null || messageId<=0) throw new ServiceException("通知标识无效");
        var notice=mapper.ownNotification(userId,messageId);
        if(notice==null) throw new ServiceException("通知不存在或无权访问");
        Long company=companies.selectCompanyIdByUser(userId);
        if(company==null || company<=0) throw new ServiceException("请先完成企业绑定");
        var match=TARGET.matcher(String.valueOf(notice.get("target")));
        if(!match.matches()) throw new ServiceException("该通知没有可用的业务详情");
        String type=match.group(1);
        if(("interviews".equals(type)) != (match.group(3)!=null))
            throw new ServiceException("通知关联格式不正确");
        Long id;
        try {id=Long.valueOf(match.group(2));} catch(NumberFormatException ex){throw new ServiceException("通知关联标识无效");}
        Map<String,Object> row=switch(type){
            case "applications" -> mapper.applicationTarget(id,company);
            case "interviews" -> mapper.interviewTarget(id,company);
            case "reports" -> mapper.reportTarget(id,company);
            default -> null;
        };
        if(row==null) throw new ServiceException("关联记录已删除或不属于当前企业");
        var result=new LinkedHashMap<String,Object>(row);
        result.put("kind",switch(type){case "applications" -> "candidate";case "interviews" -> "interview";default -> "report";});
        result.put("messageId",messageId);
        return result;
    }
}
