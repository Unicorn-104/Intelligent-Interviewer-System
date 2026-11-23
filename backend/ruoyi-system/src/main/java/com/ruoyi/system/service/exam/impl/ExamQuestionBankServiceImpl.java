package com.ruoyi.system.service.exam.impl;

import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;

import com.alibaba.fastjson2.JSON;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.exam.IExamQuestionBankService;

@Service
public class ExamQuestionBankServiceImpl implements IExamQuestionBankService
{
    private static final int MAX_COUNT = 20;
    private static final int MAX_KEYWORD = 100;
    private static final int MAX_CONTENT = 150;

    private static final String INSERT_SQL =
            "INSERT INTO t_exam_question (eqs_type, eqs_type_name, eqs_content, eqs_options_json, " +
            "eqs_answer, eqs_analysis, eqs_score, eqs_difficulty, eqs_company_id, eqs_skill_tag, eqs_category) " +
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public List<Map<String, Object>> searchPublic(String keyword, Integer category, Integer type,
            Integer difficulty, int count)
    {
        int limit = count <= 0 ? 5 : Math.min(count, MAX_COUNT);
        StringBuilder sql = new StringBuilder(
                "SELECT e.eqs_id AS id, e.eqs_content AS content, e.eqs_type AS type, " +
                "e.eqs_type_name AS typeName, e.eqs_category AS category, e.eqs_difficulty AS difficulty " +
                "FROM t_exam_question e WHERE e.eqs_company_id IS NULL");
        List<Object> args = new ArrayList<>();
        String clean = keyword == null ? "" : keyword.trim();
        if (clean.length() > MAX_KEYWORD)
        {
            clean = clean.substring(0, MAX_KEYWORD);
        }
        if (!clean.isEmpty())
        {
            sql.append(" AND e.eqs_content LIKE ?");
            args.add("%" + clean + "%");
        }
        if (category != null)
        {
            sql.append(" AND e.eqs_category = ?");
            args.add(category);
        }
        if (type != null)
        {
            sql.append(" AND e.eqs_type = ?");
            args.add(type);
        }
        if (difficulty != null)
        {
            sql.append(" AND e.eqs_difficulty = ?");
            args.add(difficulty);
        }
        sql.append(" ORDER BY e.eqs_id DESC LIMIT ?");
        args.add(limit);

        List<Map<String, Object>> rows = jdbc.queryForList(sql.toString(), args.toArray());
        for (Map<String, Object> row : rows)
        {
            Object content = row.get("content");
            if (content != null)
            {
                String text = String.valueOf(content);
                if (text.length() > MAX_CONTENT)
                {
                    row.put("content", text.substring(0, MAX_CONTENT) + "…");
                }
            }
        }
        return rows;
    }

    @Override
    public Map<String, Object> getAnswer(Long questionId)
    {
        if (questionId == null || questionId <= 0)
        {
            throw new ServiceException("题号无效", 400);
        }
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT e.eqs_id AS id, e.eqs_content AS content, e.eqs_options_json AS optionsJson, " +
                "e.eqs_answer AS answer, e.eqs_analysis AS analysis, e.eqs_type AS type, " +
                "e.eqs_category AS category, e.eqs_difficulty AS difficulty " +
                "FROM t_exam_question e WHERE e.eqs_id = ? AND e.eqs_company_id IS NULL",
                questionId);
        if (rows.isEmpty())
        {
            throw new ServiceException("题目不存在或不属于公共题库", 404);
        }
        return rows.get(0);
    }

    @Override
    public Map<String, Object> batchInsert(List<Map<String, Object>> items, Long companyId)
    {
        int inserted = 0;
        int failed = 0;
        List<String> errors = new ArrayList<>();
        List<Long> ids = new ArrayList<>();
        if (items != null)
        {
            for (Map<String, Object> item : items)
            {
                try
                {
                    Object type = toInt(item.get("type"));
                    Object typeName = str(item.get("typeName"));
                    Object content = str(item.get("content"));
                    Object options = optionsJson(item);
                    Object answer = str(item.get("answer"));
                    Object analysis = str(item.get("analysis"));
                    Object score = toScore(item.get("score"));
                    Object difficulty = toInt(item.get("difficulty"));
                    Object skillTag = str(item.get("skillTag"));
                    Object category = toCategory(item.get("category"));
                    KeyHolder keyHolder = new GeneratedKeyHolder();
                    jdbc.update(connection -> {
                        PreparedStatement ps = connection.prepareStatement(INSERT_SQL, new String[] { "eqs_id" });
                        ps.setObject(1, type);
                        ps.setObject(2, typeName);
                        ps.setObject(3, content);
                        ps.setObject(4, options);
                        ps.setObject(5, answer);
                        ps.setObject(6, analysis);
                        ps.setObject(7, score);
                        ps.setObject(8, difficulty);
                        ps.setObject(9, companyId);
                        ps.setObject(10, skillTag);
                        ps.setObject(11, category);
                        return ps;
                    }, keyHolder);
                    Number key = keyHolder.getKey();
                    if (key != null)
                    {
                        ids.add(key.longValue());
                    }
                    inserted++;
                }
                catch (Exception e)
                {
                    failed++;
                    errors.add("第 " + (inserted + failed) + " 条：" + e.getMessage());
                }
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("inserted", inserted);
        result.put("skipped", 0);       // 阶段 2 查重接入后填充
        result.put("duplicated", 0);    // 阶段 2 查重接入后填充
        result.put("failed", failed);
        result.put("errors", errors);
        result.put("ids", ids);
        return result;
    }

    /** 单选/多选才存选项 JSON，其他题型留空，与历史数据保持一致。 */
    private String optionsJson(Map<String, Object> body)
    {
        Integer type = toInt(body.get("type"));
        if (type == null || (type != 1 && type != 2))
        {
            return null;
        }
        Object raw = body.get("options");
        if (raw == null)
        {
            return null;
        }
        List<String> options = new ArrayList<>();
        if (raw instanceof List)
        {
            for (Object o : (List<?>) raw)
            {
                if (o != null && String.valueOf(o).trim().length() > 0)
                {
                    options.add(String.valueOf(o).trim());
                }
            }
        }
        return options.isEmpty() ? null : JSON.toJSONString(options);
    }

    private static String str(Object v)
    {
        return v == null ? null : String.valueOf(v).trim();
    }

    private static Integer toInt(Object v)
    {
        if (v == null)
        {
            return null;
        }
        try
        {
            if (v instanceof Number)
            {
                return ((Number) v).intValue();
            }
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? null : (int) Double.parseDouble(s);
        }
        catch (Exception e)
        {
            return null;
        }
    }

    private static BigDecimal toScore(Object v)
    {
        if (v == null)
        {
            return null;
        }
        try
        {
            if (v instanceof Number)
            {
                return new BigDecimal(String.valueOf(v));
            }
            String s = String.valueOf(v).trim();
            return s.isEmpty() ? null : new BigDecimal(s);
        }
        catch (Exception e)
        {
            return null;
        }
    }

    private static Integer toCategory(Object v)
    {
        Integer c = toInt(v);
        return (c == null || c < 1 || c > 5) ? 1 : c;
    }
}
