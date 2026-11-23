package com.ruoyi.system.mapper;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
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

    /**
     * 查询企业总数
     */
    public int selectCompanyCount();

    /**
     * 查询活跃企业数（status=1）
     */
    public int selectActiveCompanyCount();

    /**
     * 按企业全称精确查询（自助注册重复校验）
     */
    public Company selectCompanyByNameExact(@Param("cmpName") String cmpName);

    /**
     * 新增企业成员绑定
     */
    public int insertEnterpriseBinding(@Param("userId") Long userId, @Param("companyId") Long companyId,
            @Param("jobTitle") String jobTitle, @Param("status") Integer status);

    /**
     * 查询用户最新绑定及企业审核状态
     */
    public Map<String, Object> selectBindingStatusByUser(@Param("userId") Long userId);

    /**
     * 按企业同步成员绑定审核状态
     */
    public int updateBindingStatusByCompany(@Param("companyId") Long companyId, @Param("status") Integer status);

    /**
     * 回写用户所属企业
     */
    public int updateUserCompanyId(@Param("userId") Long userId, @Param("companyId") Long companyId);
}
