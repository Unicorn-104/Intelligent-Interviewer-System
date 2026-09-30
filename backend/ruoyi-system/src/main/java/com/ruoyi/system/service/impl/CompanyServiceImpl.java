package com.ruoyi.system.service.impl;

import java.util.Date;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.system.domain.Company;
import com.ruoyi.system.mapper.CompanyMapper;
import com.ruoyi.system.service.ICompanyService;

/**
 * 企业信息Service业务层处理
 *
 * @author TQY
 */
@Service
public class CompanyServiceImpl implements ICompanyService
{
    @Autowired
    private CompanyMapper companyMapper;

    @Override
    public Company selectCompanyByCmpId(Long cmpId)
    {
        return companyMapper.selectCompanyByCmpId(cmpId);
    }

    @Override
    public List<Company> selectCompanyList(Company company)
    {
        return companyMapper.selectCompanyList(company);
    }

    @Override
    public int insertCompany(Company company)
    {
        company.setCmpCreatedAt(DateUtils.getNowDate());
        return companyMapper.insertCompany(company);
    }

    @Override
    public int updateCompany(Company company)
    {
        return companyMapper.updateCompany(company);
    }

    @Override
    public int deleteCompanyByCmpId(Long cmpId)
    {
        return companyMapper.deleteCompanyByCmpId(cmpId);
    }

    @Override
    public int verifyCompany(Long cmpId, Integer verifyStatus, Long verifyBy, String rejectReason)
    {
        Company company = new Company();
        company.setCmpId(cmpId);
        company.setCmpVerifyStatus(verifyStatus);
        company.setCmpVerifyAt(DateUtils.getNowDate());
        company.setCmpVerifyBy(verifyBy);
        company.setRemark(rejectReason);
        return companyMapper.verifyCompany(company);
    }

    @Override
    public int changeStatus(Long cmpId, Integer status)
    {
        Company company = new Company();
        company.setCmpId(cmpId);
        company.setCmpStatus(status);
        return companyMapper.updateCompany(company);
    }
}
