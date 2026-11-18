package com.ruoyi.system.mapper.app;

import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.Company;

/** 企业收藏与新岗位提醒，复用现有兴趣表和消息表。 */
public interface AppCompanyMapper
{
    Map<String, Object> selectRecruiter(@Param("contactId") Long contactId);
    Company selectPublicCompany(@Param("companyId") Long companyId);

    boolean isFollowed(@Param("userId") Long userId, @Param("companyId") Long companyId);

    int follow(@Param("userId") Long userId, @Param("companyId") Long companyId);

    int unfollow(@Param("userId") Long userId, @Param("companyId") Long companyId);

    int markNotificationsRead(@Param("userId") Long userId, @Param("companyId") Long companyId);

    List<Long> selectFavoriteCompanyIds(@Param("userId") Long userId);

    Long selectLastInsertedPositionId();

    Integer lockPositionStatus(@Param("companyId") Long companyId, @Param("positionId") Long positionId);

    int notifyFollowers(@Param("companyId") Long companyId, @Param("positionId") Long positionId);
}
