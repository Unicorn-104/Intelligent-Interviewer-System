package com.ruoyi.system.service.app.pdf;

import com.ruoyi.system.config.ResumeStructureProperties;
import com.ruoyi.system.domain.app.AppResume;

/** 人工授权后，仅使用合成原文验证实际 API；不输出密钥或模型原文。 */
public class ResumeAiLiveSmoke
{
    public static void main(String[] args)
    {
        ResumeStructureProperties properties = new ResumeStructureProperties();
        properties.setApiKey(System.getenv("RESUME_STRUCTURE_API_KEY"));
        String text = """
            这是一份完全合成的测试简历，不含真实个人信息。
            职业蓝图：Java后端开发工程师
            求学足迹：2020年9月至2024年6月，就读于示例大学，计算机专业，本科。
            实践轨迹：2024年7月至今在示例科技有限公司担任研发工程师，开发订单服务。
            解决问题的经历：示例订单项目，使用Java和SQL，负责服务接口设计。
            工具箱：Java、SQL，原文不提供熟练程度。
            其他积累：示例证书信息，证书名称为模拟技术证书。
            """;
        AppResume result = new ResumeAiStructurer(properties).structure(text);
        if (!"AI".equals(result.getStructureMethod()) || result.getEducations().isEmpty()
                || result.getWorks().isEmpty() || result.getProjects().isEmpty() || result.getSkills().isEmpty())
            throw new IllegalStateException("Live AI did not return the required synthetic sections");
        System.out.println("Live DeepSeek schema mapping succeeded");
        System.out.println("Education/work/project/skill counts: " + result.getEducations().size() + "/"
                + result.getWorks().size() + "/" + result.getProjects().size() + "/" + result.getSkills().size());
        System.out.println("Additional information preserved: " + (result.getUnmappedText() != null));
    }
}
