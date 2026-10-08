package com.ruoyi.system.mapper.app;

import java.util.List;
import org.apache.ibatis.annotations.Param;
import com.ruoyi.system.domain.app.AppResume;

/** C-App 简历数据访问。 */
public interface AppResumeMapper
{
    List<AppResume> selectResumeList(@Param("userId") Long userId);
    AppResume selectResume(@Param("resumeId") Long resumeId, @Param("userId") Long userId);
    List<AppResume.Education> selectEducations(Long resumeId);
    List<AppResume.Work> selectWorks(Long resumeId);
    List<AppResume.Project> selectProjects(Long resumeId);
    List<AppResume.Skill> selectSkills(Long resumeId);
    int countActiveResumes(Long userId);
    int insertResume(AppResume resume);
    int updateResume(AppResume resume);
    int clearDefault(Long userId);
    int deleteEducations(Long resumeId);
    int deleteWorks(Long resumeId);
    int deleteProjects(Long resumeId);
    int deleteSkills(Long resumeId);
    int insertEducation(@Param("resumeId") Long resumeId, @Param("item") AppResume.Education item);
    int insertWork(@Param("resumeId") Long resumeId, @Param("item") AppResume.Work item);
    int insertProject(@Param("resumeId") Long resumeId, @Param("item") AppResume.Project item);
    int insertSkill(@Param("resumeId") Long resumeId, @Param("item") AppResume.Skill item);
}
