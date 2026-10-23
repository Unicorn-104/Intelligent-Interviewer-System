package com.ruoyi.system.service;

import java.util.List;
import com.ruoyi.system.domain.Company;

/**
 * 企业信息Service接口
 *
 * @author TQY
 */
public interface ICompanyService
{
    public Company selectCompanyByCmpId(Long cmpId);

    public List<Company> selectCompanyList(Company company);

    public int insertCompany(Company company);

    public int updateCompany(Company company);

    public int deleteCompanyByCmpId(Long cmpId);

    /**
     * 审核企业：通过或拒绝
     * @param cmpId 企业ID
     * @param verifyStatus 审核状态：1-通过，2-拒绝
     * @param verifyBy 审核人ID
     * @param rejectReason 拒绝原因（拒绝时必填）
     */
    public int verifyCompany(Long cmpId, Integer verifyStatus, Long verifyBy, String rejectReason);

    /**
     * 撤销审核：重置为待审核，清空审核人、审核时间与驳回理由
     * @param cmpId 企业ID
     */
    public int resetVerify(Long cmpId);

    /**
     * 启停用企业
     * @param cmpId 企业ID
     * @param status 状态：0-下架，1-正常
     */
    public int changeStatus(Long cmpId, Integer status);
}
