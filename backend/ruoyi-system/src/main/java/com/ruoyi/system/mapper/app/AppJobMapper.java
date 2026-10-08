package com.ruoyi.system.mapper.app;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.app.AppApplicationSummary;
import com.ruoyi.system.domain.app.AppJob;

/** C-App 岗位数据访问。 */
public interface AppJobMapper
{
    List<AppJob> selectJobs(@Param("userId") Long userId,
                            @Param("keyword") String keyword,
                            @Param("filter") String filter,
                            @Param("limit") Integer limit);

    int countNewOpportunities();

    List<AppApplicationSummary> selectRecentApplications(@Param("userId") Long userId,
                                                          @Param("limit") Integer limit);

    Long selectDefaultResumeId(@Param("userId") Long userId);

    Long selectCompanyIdByPositionId(@Param("positionId") Long positionId);

    Long selectCandidateId(@Param("userId") Long userId, @Param("companyId") Long companyId);

    int insertCandidate(@Param("userId") Long userId,
                        @Param("companyId") Long companyId,
                        @Param("resumeId") Long resumeId);

    int countApplication(@Param("candidateId") Long candidateId,
                         @Param("positionId") Long positionId);

    int insertApplication(@Param("candidateId") Long candidateId,
                          @Param("positionId") Long positionId,
                          @Param("resumeId") Long resumeId);
}
