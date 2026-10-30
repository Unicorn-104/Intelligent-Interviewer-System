package com.ruoyi.system.service.app.pdf;

import java.time.LocalDate;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.system.domain.agent.AgentResumeDetail;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.impl.agent.AgentApplicationServiceImpl;
import static org.junit.jupiter.api.Assertions.*;

class ResumeAiFieldMapperTest
{
    private final ObjectMapper json = new ObjectMapper();

    @Test
    void mapsSeparateWorkAndInternshipListsWithoutLosingEither() throws Exception
    {
        AppResume draft = new ResumeAiFieldMapper().map(json.readTree("""
                {"工作经历":[{"公司":"示例公司","职位":"工程师"}],
                 "实习经历":[{"公司":"实习公司","职位":"实习工程师"}]}
                """));
        assertEquals(2, draft.getWorks().size());
        assertEquals("示例公司", draft.getWorks().get(0).getCompany());
        assertEquals("实习公司", draft.getWorks().get(1).getCompany());
    }

    @Test
    void canonicalWorkAndInternshipsDoNotDuplicateIdenticalRecords() throws Exception
    {
        AppResume draft = new ResumeAiFieldMapper().map(json.readTree("""
                {"works":[{"company":"示例公司","position":"实习工程师"}],
                 "internships":[{"company":"示例公司","position":"实习工程师"}]}
                """));
        assertEquals(1, draft.getWorks().size());
    }

    @Test
    void aiFieldsMapIntoCorrespondingPcFieldsIncludingDegreeRoleAndDates() throws Exception
    {
        AppResume source = new ResumeAiFieldMapper().map(json.readTree("""
                {"jobDirection":"后端研发",
                 "educations":[{"school":"示例学院","major":"软件","degree":"大专","startDate":"2020年9月","endDate":"2023年6月"}],
                 "works":[{"company":"示例公司","position":"工程师","department":"研发部","endDate":"至今"}],
                 "projects":[{"name":"示例项目","role":"负责人","techStack":"Java","description":"项目描述，不是工作描述"}],
                 "skills":[{"name":"Java","level":null}]}
                """));
        AgentResumeDetail draft = ReflectionTestUtils.invokeMethod(new AgentApplicationServiceImpl(), "toAgentResume", source);
        assertNotNull(draft);
        assertEquals("后端研发", draft.getTargetRole());
        assertEquals("示例学院", draft.getEducations().get(0).getSchool());
        assertEquals("软件", draft.getEducations().get(0).getMajor());
        assertEquals(2, draft.getEducations().get(0).getDegree());
        assertEquals(LocalDate.of(2020, 9, 1), ((java.sql.Date) draft.getEducations().get(0).getStartDate()).toLocalDate());
        assertEquals("示例公司", draft.getWorks().get(0).getCompany());
        assertEquals("工程师", draft.getWorks().get(0).getPosition());
        assertTrue(draft.getWorks().get(0).getCurrent());
        assertNull(draft.getWorks().get(0).getEndDate());
        assertEquals("负责人", draft.getProjects().get(0).getRole());
        assertEquals("Java", draft.getProjects().get(0).getTechStack());
        assertNull(draft.getSkills().get(0).getLevel());
    }
}
