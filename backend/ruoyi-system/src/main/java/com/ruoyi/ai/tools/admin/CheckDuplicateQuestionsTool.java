package com.ruoyi.ai.tools.admin;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.ruoyi.ai.core.AbstractAgentTool;
import com.ruoyi.ai.core.ToolArgs;
import com.ruoyi.ai.core.ToolContext;
import com.ruoyi.ai.core.ToolResult;

/**
 * 题库查重预检：只读。
 *
 * <p>不新增哈希列、不改导入与写入路径，运行时把待检题干与现有题库归一化后
 * 比对字符二元组重合度；结果仅作预检参考，不参与任何落库判定。</p>
 */
@Component
public class CheckDuplicateQuestionsTool extends AbstractAgentTool
{
    private static final int MAX_CHECK = 5;
    private static final int MAX_CANDIDATES = 5000;
    private static final int TOP_MATCHES = 3;
    private static final double DEFAULT_THRESHOLD = 0.8;

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public String name()
    {
        return "check_duplicate_questions";
    }

    @Override
    public ObjectNode definition(ObjectMapper json)
    {
        ObjectNode params = json.createObjectNode();
        params.put("type", "object");
        ObjectNode props = params.putObject("properties");
        props.putObject("bankType").put("type", "string")
                .put("description", "platform 平台题库（默认）或 enterprise 企业题库")
                .put("enum", json.createArrayNode().add("platform").add("enterprise"));
        props.putObject("companyId").put("type", "integer").put("description", "企业题库必填，平台题库忽略");
        ObjectNode contents = props.putObject("contents");
        contents.put("type", "array").put("description", "待检题干文本，最多 5 条").put("maxItems", MAX_CHECK);
        contents.putObject("items").put("type", "string");
        ObjectNode ids = props.putObject("ids");
        ids.put("type", "array").put("description", "按已有题号查重，最多 5 个").put("maxItems", MAX_CHECK);
        ids.putObject("items").put("type", "integer");
        props.putObject("threshold").put("type", "number").put("minimum", 0.6).put("maximum", 1.0)
                .put("description", "相似度阈值，默认 0.8");
        return toolDef("题库查重预检（只读，不修改题目）：把待检题干或已有题号与当前题库比对，"
                + "返回相似度最高的疑似重复题；默认仅平台题库", params);
    }

    @Override
    public ToolResult execute(ToolContext ctx, JsonNode args)
    {
        String bankType = ToolArgs.text(args, "bankType", 20);
        if (bankType.isEmpty())
        {
            bankType = "platform";
        }
        if (!"platform".equals(bankType) && !"enterprise".equals(bankType))
        {
            return ToolResult.read("bankType 只支持 platform 或 enterprise。");
        }
        Long companyId = QuestionBankSupport.companyIdOf(bankType, args);
        Set<Long> ids = ToolArgs.longSet(args.path("ids"));
        List<String> inputs = readContents(args);
        if (ids.size() > MAX_CHECK || inputs.size() > MAX_CHECK)
        {
            return ToolResult.read("一次最多检查 " + MAX_CHECK + " 条，请分批提交。");
        }
        if (ids.isEmpty() && inputs.isEmpty())
        {
            return ToolResult.read("请提供待检题干 contents 或已有题号 ids。");
        }

        List<Candidate> targets = new ArrayList<>();
        List<Long> missing = new ArrayList<>();
        for (Long id : ids)
        {
            String content = contentOf(id, bankType, companyId);
            if (content == null)
            {
                missing.add(id);
            }
            else
            {
                targets.add(new Candidate(id, content));
            }
        }
        for (String text : inputs)
        {
            targets.add(new Candidate(null, text));
        }
        if (targets.isEmpty())
        {
            return ToolResult.read("这些题号在指定题库中都不存在，无法查重。");
        }

        List<Candidate> candidates = loadCandidates(bankType, companyId, ids);
        double threshold = thresholdOf(args);
        StringBuilder out = new StringBuilder("已检查 ").append(targets.size()).append(" 条，题库 ")
                .append(candidates.size()).append(" 题参与比对");
        if (candidates.size() == MAX_CANDIDATES)
        {
            out.append("（达到上限 ").append(MAX_CANDIDATES).append("，仅比对最近部分题目）");
        }
        out.append("。\n");
        if (!missing.isEmpty())
        {
            out.append("题号 ").append(joinIds(missing)).append(" 不存在，已跳过。\n");
        }

        for (int i = 0; i < targets.size(); i++)
        {
            Candidate target = targets.get(i);
            List<Match> matches = matches(target, candidates, threshold);
            out.append(i + 1).append(". ");
            if (target.id != null)
            {
                out.append("#").append(target.id).append(" ");
            }
            out.append("“").append(ToolArgs.cut(target.content, 40)).append("” → ");
            if (matches.isEmpty())
            {
                out.append("未发现相似度 ≥ ").append(percent(threshold)).append(" 的题目。\n");
                continue;
            }
            out.append("疑似重复：");
            for (int j = 0; j < matches.size(); j++)
            {
                Match m = matches.get(j);
                if (j > 0)
                {
                    out.append("；");
                }
                out.append('#').append(m.id).append(" 相似度 ").append(percent(m.score))
                        .append(" “").append(ToolArgs.cut(m.content, 30)).append("”");
            }
            out.append('\n');
        }
        out.append("注：只读比对，未修改任何题目；相似度按题干字符重合度估算，仅作预检参考。");
        return ToolResult.read(out.toString());
    }

    private List<String> readContents(JsonNode args)
    {
        List<String> list = new ArrayList<>();
        JsonNode node = args.path("contents");
        if (node.isTextual())
        {
            addContent(list, node.asText(""));
        }
        else if (node.isArray())
        {
            for (JsonNode item : node)
            {
                addContent(list, item.asText(""));
            }
        }
        return list;
    }

    private void addContent(List<String> list, String raw)
    {
        String text = raw == null ? "" : raw.trim();
        if (text.isEmpty())
        {
            return;
        }
        list.add(text.length() > QuestionBankSupport.MAX_CONTENT
                ? text.substring(0, QuestionBankSupport.MAX_CONTENT) : text);
    }

    private double thresholdOf(JsonNode args)
    {
        if (!args.has("threshold"))
        {
            return DEFAULT_THRESHOLD;
        }
        double value = args.path("threshold").asDouble(DEFAULT_THRESHOLD);
        return value < 0.6 || value > 1.0 ? DEFAULT_THRESHOLD : value;
    }

    private String contentOf(long id, String bankType, Long companyId)
    {
        List<Object> params = new ArrayList<>();
        params.add(id);
        String sql = "SELECT eqs_content FROM t_exam_question WHERE eqs_id = ?"
                + scopeSqlHeader(bankType, companyId, params);
        List<String> rows = jdbc.queryForList(sql, String.class, params.toArray());
        return rows.isEmpty() ? null : rows.get(0);
    }

    /** 候选题排除了被检查的题号自身，避免同一题与自己做无意义比对。 */
    private List<Candidate> loadCandidates(String bankType, Long companyId, Set<Long> excludeIds)
    {
        List<Object> params = new ArrayList<>();
        StringBuilder sql = new StringBuilder("SELECT eqs_id AS id, eqs_content AS content FROM t_exam_question WHERE 1 = 1");
        sql.append(scopeSqlHeader(bankType, companyId, params));
        if (!excludeIds.isEmpty())
        {
            sql.append(" AND eqs_id NOT IN (")
               .append(String.join(",", java.util.Collections.nCopies(excludeIds.size(), "?")))
               .append(")");
            params.addAll(excludeIds);
        }
        sql.append(" ORDER BY eqs_id DESC LIMIT ?");
        params.add(MAX_CANDIDATES);

        List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), params.toArray());
        List<Candidate> candidates = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows)
        {
            Object id = row.get("id");
            Object content = row.get("content");
            if (id instanceof Number && content != null)
            {
                candidates.add(new Candidate(((Number) id).longValue(), String.valueOf(content)));
            }
        }
        return candidates;
    }

    private String scopeSqlHeader(String bankType, Long companyId, List<Object> params)
    {
        if ("platform".equals(bankType))
        {
            return " AND eqs_company_id IS NULL";
        }
        params.add(companyId);
        return " AND eqs_company_id = ?";
    }

    private List<Match> matches(Candidate target, List<Candidate> candidates, double threshold)
    {
        List<Match> found = new ArrayList<>();
        if (target.grams.isEmpty())
        {
            return found;
        }
        for (Candidate candidate : candidates)
        {
            double score = jaccard(target.grams, candidate.grams);
            if (score >= threshold)
            {
                found.add(new Match(candidate.id, candidate.content, score));
            }
        }
        found.sort((a, b) -> Double.compare(b.score, a.score));
        return found.size() > TOP_MATCHES ? found.subList(0, TOP_MATCHES) : found;
    }

    private double jaccard(Set<String> left, Set<String> right)
    {
        if (left.isEmpty() || right.isEmpty())
        {
            return 0;
        }
        Set<String> small = left.size() <= right.size() ? left : right;
        Set<String> large = left.size() <= right.size() ? right : left;
        int shared = 0;
        for (String gram : small)
        {
            if (large.contains(gram))
            {
                shared++;
            }
        }
        int union = left.size() + right.size() - shared;
        return union <= 0 ? 0 : (double) shared / union;
    }

    private String percent(double value)
    {
        return Math.round(value * 100) + "%";
    }

    private String joinIds(List<Long> ids)
    {
        StringBuilder sb = new StringBuilder();
        for (Long id : ids)
        {
            if (sb.length() > 0)
            {
                sb.append('、');
            }
            sb.append('#').append(id);
        }
        return sb.toString();
    }

    private static final class Candidate
    {
        private final Long id;

        private final String content;

        private final Set<String> grams;

        private Candidate(Long id, String content)
        {
            this.id = id;
            this.content = content == null ? "" : content.trim();
            this.grams = grams(this.content);
        }
    }

    private static final class Match
    {
        private final Long id;

        private final String content;

        private final double score;

        private Match(Long id, String content, double score)
        {
            this.id = id;
            this.content = content;
            this.score = score;
        }
    }

    /** 题干归一：NFKC 处理全半角，去掉标点与空白，保留中英文与数字。 */
    private static String normalize(String text)
    {
        String folded = Normalizer.normalize(text == null ? "" : text, Normalizer.Form.NFKC).toLowerCase();
        StringBuilder sb = new StringBuilder(folded.length());
        for (char c : folded.toCharArray())
        {
            if (Character.isLetterOrDigit(c))
            {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    private static Set<String> grams(String text)
    {
        String normalized = normalize(text);
        Set<String> set = new HashSet<>();
        if (normalized.length() == 1)
        {
            set.add(normalized);
            return set;
        }
        for (int i = 0; i + 1 < normalized.length(); i++)
        {
            set.add(normalized.substring(i, i + 2));
        }
        return set;
    }
}
