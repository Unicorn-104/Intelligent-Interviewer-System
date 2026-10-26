package com.ruoyi.enterprise.mapper;

import java.util.Map;
import org.apache.ibatis.annotations.Param;

/**
 * 企业端简历批量导入：账号匹配、候选人建档与简历关联
 */
public interface EnterpriseResumeImportMapper
{
    /** 当前登录用户绑定的企业ID */
    Long selectCompanyIdByUser(@Param("userId") Long userId);

    /** 按手机号匹配已注册用户 */
    Long selectUserIdByPhone(@Param("phone") String phone);

    /** 按邮箱匹配已注册用户 */
    Long selectUserIdByEmail(@Param("email") String email);

    /** 用户昵称（候选人姓名） */
    String selectNickName(@Param("userId") Long userId);

    /** 候选人在当前企业的档案 */
    Map<String, Object> selectCandidate(@Param("userId") Long userId, @Param("companyId") Long companyId);

    /** 在当前企业新建候选人档案 */
    int insertCandidate(@Param("userId") Long userId, @Param("companyId") Long companyId);

    /** 回写候选人当前档案简历 */
    int updateCandidateResume(@Param("talId") Long talId, @Param("resumeId") Long resumeId);

    /** 同一用户下同名简历ID（用于去重） */
    Long selectResumeIdByName(@Param("userId") Long userId, @Param("resumeName") String resumeName);
}
