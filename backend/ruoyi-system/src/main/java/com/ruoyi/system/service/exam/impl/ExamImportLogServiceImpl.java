package com.ruoyi.system.service.exam.impl;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;

import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.service.exam.IExamImportLogService;

@Service
public class ExamImportLogServiceImpl implements IExamImportLogService
{
    private static final String INSERT_BATCH =
            "INSERT INTO t_exam_question_import_batch "
            + "(eqb_type, eqb_file_name, eqb_company_id, eqb_total, eqb_inserted, eqb_failed, eqb_question_ids, eqb_operator) "
            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";

    @Autowired
    private JdbcTemplate jdbc;

    @Override
    public Long record(Integer type, String fileName, Long companyId, int total, int inserted, int failed,
            List<Long> questionIds, String operator)
    {
        String ids = joinIds(questionIds);
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(INSERT_BATCH, new String[] { "eqb_id" });
            ps.setInt(1, type == null ? 1 : type);
            ps.setString(2, fileName);
            if (companyId == null)
            {
                ps.setNull(3, java.sql.Types.BIGINT);
            }
            else
            {
                ps.setLong(3, companyId);
            }
            ps.setInt(4, total);
            ps.setInt(5, inserted);
            ps.setInt(6, failed);
            ps.setString(7, ids);
            ps.setString(8, operator);
            return ps;
        }, keyHolder);
        Number key = keyHolder.getKey();
        return key == null ? null : key.longValue();
    }

    @Override
    public Map<String, Object> list(int pageNum, int pageSize)
    {
        int size = pageSize <= 0 ? 10 : Math.min(pageSize, 50);
        int page = pageNum <= 0 ? 1 : pageNum;
        int offset = (page - 1) * size;
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT b.eqb_id AS id, b.eqb_type AS type, b.eqb_file_name AS fileName, "
                + "b.eqb_company_id AS companyId, c.cmp_name AS companyName, "
                + "b.eqb_total AS total, b.eqb_inserted AS inserted, b.eqb_failed AS failed, "
                + "b.eqb_status AS status, b.eqb_operator AS operator, b.eqb_created_at AS createTime "
                + "FROM t_exam_question_import_batch b LEFT JOIN t_cmp c ON c.cmp_id = b.eqb_company_id "
                + "ORDER BY b.eqb_id DESC LIMIT ? OFFSET ?",
                size, offset);
        Integer count = jdbc.queryForObject("SELECT COUNT(1) FROM t_exam_question_import_batch", Integer.class);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("rows", rows);
        result.put("total", count == null ? 0 : count);
        return result;
    }

    @Override
    public Map<String, Object> undo(Long batchId, String operator)
    {
        if (batchId == null || batchId <= 0)
        {
            throw new ServiceException("批次号无效", 400);
        }
        List<Map<String, Object>> batches = jdbc.queryForList(
                "SELECT eqb_status AS status, eqb_question_ids AS ids, eqb_company_id AS companyId "
                + "FROM t_exam_question_import_batch WHERE eqb_id = ?", batchId);
        if (batches.isEmpty())
        {
            throw new ServiceException("导入记录不存在", 404);
        }
        Map<String, Object> batch = batches.get(0);
        Object statusObj = batch.get("status");
        if (statusObj != null && Integer.parseInt(String.valueOf(statusObj)) == 1)
        {
            throw new ServiceException("该批次已撤销，不能重复操作", 409);
        }
        Set<Long> ids = parseIds(batch.get("ids"));
        int deleted = 0;
        int referenced = 0;
        if (!ids.isEmpty())
        {
            String inClause = joinIds(new ArrayList<>(ids));
            Set<Long> alive = new HashSet<>();
            jdbc.query("SELECT eqs_id FROM t_exam_question WHERE eqs_id IN (" + inClause + ")",
                    (ResultSet rs) -> {
                        alive.add(rs.getLong(1));
                    });
            Set<Long> locked = new HashSet<>();
            jdbc.query("SELECT DISTINCT epq_question_id FROM t_exam_paper_question WHERE epq_question_id IN ("
                    + inClause + ")", (ResultSet rs) -> {
                        locked.add(rs.getLong(1));
                    });
            jdbc.query("SELECT DISTINCT ean_question_id FROM t_exam_answer WHERE ean_question_id IN ("
                    + inClause + ")", (ResultSet rs) -> {
                        locked.add(rs.getLong(1));
                    });
            referenced = locked.size();
            List<Long> deletable = new ArrayList<>();
            for (Long id : ids)
            {
                if (alive.contains(id) && !locked.contains(id))
                {
                    deletable.add(id);
                }
            }
            if (!deletable.isEmpty())
            {
                deleted = jdbc.update("DELETE FROM t_exam_question WHERE eqs_id IN ("
                        + joinIds(deletable) + ")");
            }
        }
        jdbc.update("UPDATE t_exam_question_import_batch SET eqb_status = 1 WHERE eqb_id = ?", batchId);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("batchId", batchId);
        result.put("deleted", deleted);
        result.put("skipped", ids.size() - deleted);
        result.put("referenced", referenced);
        result.put("status", 1);
        return result;
    }

    private static String joinIds(List<Long> ids)
    {
        if (ids == null || ids.isEmpty())
        {
            return null;
        }
        StringBuilder sb = new StringBuilder();
        for (Long id : ids)
        {
            if (id == null || id <= 0)
            {
                continue;
            }
            if (sb.length() > 0)
            {
                sb.append(',');
            }
            sb.append(id);
        }
        return sb.length() == 0 ? null : sb.toString();
    }

    private static Set<Long> parseIds(Object raw)
    {
        Set<Long> ids = new LinkedHashSet<>();
        if (raw == null)
        {
            return ids;
        }
        for (String part : String.valueOf(raw).split(","))
        {
            String t = part.trim();
            if (t.isEmpty())
            {
                continue;
            }
            try
            {
                long v = Long.parseLong(t);
                if (v > 0)
                {
                    ids.add(v);
                }
            }
            catch (NumberFormatException ignored)
            {
                // 脏数据跳过，不影响其余题目撤销
            }
        }
        return ids;
    }
}
