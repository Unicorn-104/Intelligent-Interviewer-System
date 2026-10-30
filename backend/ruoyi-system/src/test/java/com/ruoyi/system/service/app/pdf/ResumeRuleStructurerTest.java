package com.ruoyi.system.service.app.pdf;

import java.time.LocalDate;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.system.config.ResumeStructureProperties;
import com.ruoyi.system.domain.app.AppResume;
import com.ruoyi.system.service.app.impl.AppResumeServiceImpl;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class ResumeRuleStructurerTest
{
    private final ResumeRuleStructurer structurer = new ResumeRuleStructurer();

    @Test
    void mapsDateFirstSinglePipeColumnsWithoutMixingSections()
    {
        AppResume draft = structurer.structure("""
                求职意向：后端开发
                教育背景
                2018.09-2022.06 | 示例大学 | 计算机科学 | 本科
                工作经历
                2022.07-至今 | 示例科技公司 | 后端工程师
                工作内容：开发服务
                项目经历
                项目名称：订单平台
                担任角色：后端开发
                技术栈：Java、SQL
                项目描述：为示例大学和另一科技公司提供服务
                负责交易模块
                上线后提高处理效率
                专业技能
                Java、SQL
                自我评价
                喜欢研究科技公司业务
                """);
        assertEquals("后端开发", draft.getJobDirection());
        assertEquals(1, draft.getEducations().size());
        assertEquals("示例大学", draft.getEducations().get(0).getSchool());
        assertEquals("计算机科学", draft.getEducations().get(0).getMajor());
        assertEquals(3, draft.getEducations().get(0).getDegree());
        assertEquals(LocalDate.of(2018, 9, 1), draft.getEducations().get(0).getStartDate());
        assertEquals(1, draft.getWorks().size());
        assertEquals("示例科技公司", draft.getWorks().get(0).getCompany());
        assertEquals("后端工程师", draft.getWorks().get(0).getPosition());
        assertTrue(draft.getWorks().get(0).getCurrent());
        assertNull(draft.getWorks().get(0).getEndDate());
        assertEquals("工作内容：开发服务", draft.getWorks().get(0).getDescription());
        assertEquals(1, draft.getProjects().size());
        assertEquals("订单平台", draft.getProjects().get(0).getName());
        assertEquals("后端开发", draft.getProjects().get(0).getRole());
        assertEquals("Java、SQL", draft.getProjects().get(0).getTechStack());
        assertTrue(draft.getProjects().get(0).getDescription().endsWith("上线后提高处理效率"));
        assertEquals(2, draft.getSkills().size());
        assertNull(draft.getSkills().get(0).getLevel());
        assertTrue(draft.getUnmappedText().contains("喜欢研究科技公司业务"));
    }

    @Test
    void boundsWorkAndInternshipAndDoesNotInventDegreeOrPosition()
    {
        AppResume draft = structurer.structure("""
                教育经历
                示例学院
                专业：软件工程
                实习经历
                示例公司
                职位：实习工程师
                工作经验
                另一公司
                资格证书
                示例大学联合证书
                """);
        assertEquals(1, draft.getEducations().size());
        assertNull(draft.getEducations().get(0).getDegree());
        assertEquals("软件工程", draft.getEducations().get(0).getMajor());
        assertEquals(2, draft.getWorks().size());
        assertEquals("实习工程师", draft.getWorks().get(0).getPosition());
        assertNull(draft.getWorks().get(1).getPosition());
        assertTrue(draft.getUnmappedText().contains("示例大学联合证书"));
    }

    @Test
    void keepsProjectParagraphsTogetherAndStopsAtOtherSections()
    {
        AppResume draft = structurer.structure("""
                项目经验
                示例系统  2023.01-2023.06
                实现登录功能
                实现支付功能
                获得优秀评价
                项目名称：第二项目
                项目描述：第二段描述
                荣誉奖项
                优秀项目奖
                """);
        assertEquals(2, draft.getProjects().size());
        assertEquals("示例系统", draft.getProjects().get(0).getName());
        assertEquals("实现登录功能\n实现支付功能\n获得优秀评价", draft.getProjects().get(0).getDescription());
        assertEquals(LocalDate.of(2023, 6, 1), draft.getProjects().get(0).getEndDate());
        assertEquals("项目描述：第二段描述", draft.getProjects().get(1).getDescription());
    }

    @Test
    void invalidDatesStayBlankInsteadOfClampingMonths()
    {
        AppResume draft = structurer.structure("教育背景\n2020.19-2023.06 | 示例大学 | 软件 | 大专");
        assertNull(draft.getEducations().get(0).getStartDate());
        assertEquals(LocalDate.of(2023, 6, 1), draft.getEducations().get(0).getEndDate());
        assertEquals(2, draft.getEducations().get(0).getDegree());
        assertTrue(draft.getParseWarnings().stream().anyMatch(warning -> warning.contains("无效日期")));
    }

    @Test
    void reversedDatesStayBlankAndFullDatesKeepDayPrecision()
    {
        AppResume draft = structurer.structure("教育背景\n示例大学 | 2024-06-30 至 2020-09-01 | 本科\n另一大学 | 2020年9月2日 到 2024年6月3日 | 硕士");
        assertNull(draft.getEducations().get(0).getStartDate());
        assertNull(draft.getEducations().get(0).getEndDate());
        assertEquals(LocalDate.of(2020, 9, 2), draft.getEducations().get(1).getStartDate());
        assertEquals(LocalDate.of(2024, 6, 3), draft.getEducations().get(1).getEndDate());
    }

    @Test
    void noHeadingsDoesNotTreatMentionedOrganizationsAsExperience()
    {
        AppResume draft = structurer.structure("项目为示例大学和示例公司开发了一套平台\n获得另一个学院的证书");
        assertTrue(draft.getEducations().isEmpty());
        assertTrue(draft.getWorks().isEmpty());
        assertTrue(draft.getUnmappedText().contains("证书"));
    }

    @Test
    void unknownSkillsAndMissingSectionsArePreservedForReview()
    {
        AppResume draft = structurer.structure("专业技能：Java、SQL\n熟悉业务建模，能够独立完成服务开发。\n校园经历\n组织活动");
        assertEquals(2, draft.getSkills().size());
        assertTrue(draft.getUnmappedText().contains("熟悉业务建模"));
        assertTrue(draft.getUnmappedText().contains("组织活动"));
    }

    @Test
    void standaloneDatesBetweenRecordsAreNotCopiedToWrongExperience()
    {
        AppResume draft = structurer.structure("教育背景\n2018.09-2022.06\n示例大学 | 本科\n2022.09-2025.06\n另一大学 | 硕士");
        assertEquals(LocalDate.of(2018, 9, 1), draft.getEducations().get(0).getStartDate());
        assertNull(draft.getEducations().get(1).getStartDate());
        assertTrue(draft.getUnmappedText().contains("2022.09-2025.06"));
    }

    @Test
    void fallbackServiceRetainsMappingWarningsAndOriginalText()
    {
        String text = "教育背景\n示例大学 | 2020.09-2024.06 | 本科";
        ResumePdfParser parser = mock(ResumePdfParser.class);
        when(parser.parse(any(byte[].class))).thenReturn(new ResumePdfParser.Result(text, "OCR"));
        AppResumeServiceImpl service = new AppResumeServiceImpl();
        ReflectionTestUtils.setField(service, "pdfParser", parser);
        ReflectionTestUtils.setField(service, "aiStructurer", mock(ResumeAiStructurer.class));
        ReflectionTestUtils.setField(service, "structureProperties", new ResumeStructureProperties());
        AppResume draft = service.parsePdf(new byte[] { 1 }, "synthetic.pdf");
        assertEquals("RULE", draft.getStructureMethod());
        assertEquals("OCR", draft.getParseMethod());
        assertEquals(text, draft.getExtractedText());
        assertTrue(draft.getParseWarnings().stream().anyMatch(warning -> warning.contains("日期精度")));
        assertTrue(draft.getParseWarnings().stream().anyMatch(warning -> warning.contains("AI")));
    }
}
