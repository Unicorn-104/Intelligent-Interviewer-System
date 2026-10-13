package com.ruoyi.enterprise.service.impl;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.DateUtils;
import com.ruoyi.enterprise.mapper.EnterpriseJdMapper;
import com.ruoyi.enterprise.service.IEnterpriseJdService;

/**
 * 企业端 - 岗位画像（JD Profile）服务实现
 *
 * <p>依据《业务功能分析》UC-01：解析 JD 文本提取学历、年限、
 * 技能标签等硬性指标与软性要求，生成结构化岗位画像。</p>
 *
 * @author enterprise
 */
@Service
public class EnterpriseJdServiceImpl implements IEnterpriseJdService
{
    /** 技能标签词典（UC-01 硬性指标：技能标签提取用） */
    private static final String[] SKILL_DICTIONARY = {
        "Java", "Spring Boot", "Spring Cloud", "Spring", "MySQL", "Redis", "Kafka", "RocketMQ",
        "微服务", "分布式", "Docker", "Kubernetes", "K8s", "Flutter", "Dart", "Android", "iOS",
        "React", "Vue", "TypeScript", "JavaScript", "NLP", "机器学习", "深度学习", "PyTorch",
        "TensorFlow", "LLM", "大模型", "RAG", "Prompt", "Figma", "Axure", "产品设计",
        "数据分析", "SQL", "Python", "Go", "C++", "Elasticsearch", "Hadoop", "Spark", "算法"
    };

    /** 软性要求关键词词典（UC-01 软性要求提取用） */
    private static final String[] SOFT_DICTIONARY = {
        "沟通", "协作", "责任心", "抗压", "学习能力", "团队", "自驱", "owner", "技术分享"
    };

    private static final Pattern YEARS_PATTERN = Pattern.compile("(\\d+)\\s*年");

    @Autowired
    private EnterpriseJdMapper jdMapper;

    @Override
    public Map<String, Object> parseJd(Long positionId, String jdText)
    {
        if (positionId == null)
        {
            throw new ServiceException("岗位ID不能为空");
        }
        if (jdText == null || jdText.trim().isEmpty())
        {
            throw new ServiceException("JD 文本不能为空");
        }
        String text = jdText.trim();

        // 硬性指标：学历提取（按优先级匹配首个出现的学历关键词）
        String education = matchEducation(text);
        // 硬性指标：年限提取（如"5年以上"）
        String years = matchYears(text);
        // 硬性指标：技能标签（词典匹配）
        List<String> skills = matchSkills(text);
        // 软性要求：词典匹配
        List<String> softRequirements = matchSoft(text);

        // 画像快照（写入 t_pos.pos_jd_json）
        Map<String, Object> profile = new LinkedHashMap<>();
        profile.put("education", education);
        profile.put("years", years);
        profile.put("skills", skills);
        profile.put("softRequirements", softRequirements);
        profile.put("summary", text.length() > 200 ? text.substring(0, 200) + "…" : text);
        profile.put("parsedAt", DateUtils.getTime());
        String jdJson = JSON.toJSONString(profile);

        // 落库：画像快照 + 技能标签（先删后插，保持幂等）
        if (jdMapper.updatePositionJd(positionId, jdJson) == 0)
        {
            throw new ServiceException("岗位不存在或已删除");
        }
        jdMapper.deletePositionSkills(positionId);
        for (String skill : skills)
        {
            jdMapper.insertPositionSkill(positionId, skill, 1);
        }
        return profile;
    }

    @Override
    public Map<String, Object> getJdProfile(Long positionId)
    {
        Map<String, Object> position = jdMapper.selectPositionJd(positionId);
        if (position == null)
        {
            throw new ServiceException("岗位不存在");
        }
        List<Map<String, Object>> skills = jdMapper.selectPositionSkills(positionId);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("positionId", position.get("positionId"));
        result.put("title", position.get("title"));
        result.put("department", position.get("department"));
        // pos_jd_json 为空表示尚未生成画像
        result.put("jdProfile", position.get("jdJson") == null ? null
                : JSON.parseObject(String.valueOf(position.get("jdJson"))));
        result.put("skills", skills);
        return result;
    }

    /** 学历关键词匹配（博士>硕士>研究生>本科>学士>大专>专科） */
    private String matchEducation(String text)
    {
        String[][] groups = {
            {"博士"}, {"硕士", "研究生"}, {"本科", "学士"}, {"大专", "专科"}
        };
        for (String[] group : groups)
        {
            for (String keyword : group)
            {
                if (text.contains(keyword))
                {
                    return group[0] + "及以上";
                }
            }
        }
        return "不限";
    }

    /** 年限提取："5年" / "5年以上" / "3-5年" */
    private String matchYears(String text)
    {
        Matcher matcher = YEARS_PATTERN.matcher(text);
        if (matcher.find())
        {
            return matcher.group(1) + "年以上";
        }
        return "不限";
    }

    /** 技能标签词典匹配（去重、保持词典顺序） */
    private List<String> matchSkills(String text)
    {
        List<String> matched = new ArrayList<>();
        for (String skill : SKILL_DICTIONARY)
        {
            if (text.toLowerCase().contains(skill.toLowerCase()))
            {
                matched.add(skill);
            }
        }
        return matched;
    }

    /** 软性要求词典匹配（去重、保持词典顺序） */
    private List<String> matchSoft(String text)
    {
        List<String> matched = new ArrayList<>();
        for (String keyword : SOFT_DICTIONARY)
        {
            if (text.contains(keyword))
            {
                matched.add(keyword);
            }
        }
        return matched;
    }
}
