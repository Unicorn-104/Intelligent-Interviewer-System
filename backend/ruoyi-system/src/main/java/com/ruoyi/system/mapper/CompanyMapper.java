package com.ruoyi.system.mapper;

import java.util.List;
import com.ruoyi.system.domain.Company;

/**
 * 企业信息Mapper接口
 *
 * @author TQY
 */
public interface CompanyMapper
{
    public Company selectCompanyByCmpId(Long cmpId);

    public List<Company> selectCompanyList(Company company);

    public int insertCompany(Company company);

    public int updateCompany(Company company);

    public int deleteCompanyByCmpId(Long cmpId);

    /**
     * 审核企业（更新认证状态）
     */
    public int verifyCompany(Company company);
}
