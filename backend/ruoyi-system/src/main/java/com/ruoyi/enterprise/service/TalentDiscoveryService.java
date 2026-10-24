package com.ruoyi.enterprise.service;

import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.PageUtils;
import com.ruoyi.enterprise.domain.TalentSearchCriteria;
import com.ruoyi.enterprise.mapper.TalentDiscoveryMapper;
import com.ruoyi.system.mapper.DashboardMapper;

@Service
public class TalentDiscoveryService
{
    @Autowired private TalentDiscoveryMapper discoveryMapper;
    @Autowired private DashboardMapper dashboardMapper;
    public List<Map<String,Object>> list(Long viewerId, String keyword, String direction,
            Integer currentStatus, Integer pageNum, Integer pageSize, TalentSearchCriteria criteria)
    {
        requireEnterprise(viewerId);
        if (pageNum == null || pageSize == null || pageNum < 1 || pageNum > 100000 || pageSize < 1 || pageSize > 100)
            throw new ServiceException("分页参数超出范围");
        if (currentStatus != null && (currentStatus < 1 || currentStatus > 3))
            throw new ServiceException("求职状态仅支持1至3，不是招聘流程状态");
        String search = text(keyword, 100), intent = text(direction, 100);
        if (criteria == null) criteria = new TalentSearchCriteria();
        criteria.validate();
        PageUtils.startPage(pageNum, pageSize);
        return discoveryMapper.selectUsers(search, intent, currentStatus, criteria);
    }
    public Map<String,Object> detail(Long viewerId, Long userId)
    {
        requireEnterprise(viewerId);
        if (userId == null || userId <= 0) throw new ServiceException("用户编号无效");
        Map<String,Object> row = discoveryMapper.selectUser(userId);
        if (row == null) throw new ServiceException("该人才不存在或当前不可访问");
        return row;
    }
    public Map<String,Object> options(Long viewerId)
    {
        requireEnterprise(viewerId);
        return Map.of("directions", discoveryMapper.selectDirections(), "tags", List.of(),
            "currentCities", discoveryMapper.selectCities("current"),
            "targetCities", discoveryMapper.selectCities("target"), "searchFilterVersion", 2, "directoryVersion", 1);
    }
    private void requireEnterprise(Long viewerId)
    {
        Long company = viewerId == null || viewerId <= 0 ? null : dashboardMapper.selectCompanyIdByUser(viewerId);
        if (company == null || company <= 0) throw new ServiceException("请先完成企业绑定");
    }
    private String text(String raw, int max)
    {
        if (raw == null) return null;
        if (raw.chars().anyMatch(Character::isISOControl))
            throw new ServiceException("搜索内容长度或字符不合法");
        String value = raw.trim();
        if (value.isEmpty()) return null;
        if (value.length() > max)
            throw new ServiceException("搜索内容长度或字符不合法");
        return value;
    }
}
