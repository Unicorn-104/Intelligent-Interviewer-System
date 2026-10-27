package com.ruoyi.system.service.impl;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.system.mapper.EnterpriseSettingsMapper;
import com.ruoyi.system.service.IDataManageService;

/**
 * 企业数据管理 服务实现（导出/备份/清理）
 *
 * @author ruoyi
 */
@Service
public class DataManageServiceImpl implements IDataManageService
{
    /** 清理年限：流程结束超过 N 年 */
    private static final int CLEANUP_YEARS = 2;

    /** 备份的业务表（按 company 列过滤） */
    private static final String[][] BACKUP_TABLES = {
            { "t_cmp_dept", "company_id" },
            { "t_cmp_integration", "company_id" },
            { "t_msg_template", "tpl_company_id" },
            { "t_cmp_binding", "bnd_company_id" },
            { "t_tal", "tal_company_id" }
    };

    @Autowired
    private EnterpriseSettingsMapper settingsMapper;

    @Autowired
    private DataSource dataSource;

    @Override
    public Map<String, Object> exportResumes(Long companyId)
    {
        List<Map<String, Object>> rows = settingsMapper.selectCandidateExportRows(companyId);
        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
        String fileName = "candidates_" + companyId + "_" + stamp + ".csv";
        File dir = new File(RuoYiConfig.getProfile(), "export");
        if (!dir.exists() && !dir.mkdirs())
        {
            throw new ServiceException("导出目录创建失败");
        }
        try (Writer w = new OutputStreamWriter(new FileOutputStream(new File(dir, fileName)), StandardCharsets.UTF_8))
        {
            w.write('\ufeff');
            w.write("候选人,应聘岗位,流程状态,入库时间\n");
            for (Map<String, Object> row : rows)
            {
                w.write(csv(row.get("candidateName")) + "," + csv(row.get("positionTitle")) + ","
                        + csv(statusText(row.get("status"))) + "," + csv(row.get("createdAt")) + "\n");
            }
        }
        catch (Exception e)
        {
            throw new ServiceException("导出失败：" + e.getMessage());
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("url", "/profile/export/" + fileName);
        result.put("count", rows.size());
        return result;
    }

    @Override
    public Map<String, Object> backup(Long companyId)
    {
        String stamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
        String fileName = "backup_company_" + companyId + "_" + stamp + ".sql";
        File dir = new File(RuoYiConfig.getProfile(), "backup");
        if (!dir.exists() && !dir.mkdirs())
        {
            throw new ServiceException("备份目录创建失败");
        }
        try (Connection conn = dataSource.getConnection();
                Writer w = new OutputStreamWriter(new FileOutputStream(new File(dir, fileName)), StandardCharsets.UTF_8);
                Statement st = conn.createStatement())
        {
            w.write("-- recruit_agent company " + companyId + " backup " + stamp + "\n");
            for (String[] table : BACKUP_TABLES)
            {
                w.write("\n-- " + table[0] + "\n");
                try (ResultSet rs = st.executeQuery("select * from " + table[0] + " where " + table[1] + " = " + companyId))
                {
                    ResultSetMetaData md = rs.getMetaData();
                    int cols = md.getColumnCount();
                    while (rs.next())
                    {
                        StringBuilder names = new StringBuilder();
                        StringBuilder values = new StringBuilder();
                        for (int i = 1; i <= cols; i++)
                        {
                            if (i > 1)
                            {
                                names.append(", ");
                                values.append(", ");
                            }
                            names.append(md.getColumnName(i));
                            Object v = rs.getObject(i);
                            values.append(sqlValue(v));
                        }
                        w.write("insert into " + table[0] + " (" + names + ") values (" + values + ");\n");
                    }
                }
            }
        }
        catch (Exception e)
        {
            throw new ServiceException("备份失败：" + e.getMessage());
        }
        String time = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date());
        recordBackupTime(companyId, time);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("fileName", fileName);
        result.put("backupTime", time);
        return result;
    }

    @Override
    public String lastBackupTime(Long companyId)
    {
        return settingsMapper.selectConfigValue("enterprise.lastBackup." + companyId);
    }

    @Override
    public List<Map<String, Object>> cleanupPreview(Long companyId, int years)
    {
        return settingsMapper.selectCleanupRows(companyId, years);
    }

    @Override
    public int cleanupExecute(Long companyId, List<Long> talIds)
    {
        if (talIds == null || talIds.isEmpty())
        {
            return 0;
        }
        // 以预览条件复核，防止越权/越期删除
        Set<Long> allowed = new HashSet<>();
        for (Map<String, Object> row : settingsMapper.selectCleanupRows(companyId, CLEANUP_YEARS))
        {
            allowed.add(((Number) row.get("talId")).longValue());
        }
        List<Long> targets = new ArrayList<>();
        for (Long id : talIds)
        {
            if (id != null && allowed.contains(id))
            {
                targets.add(id);
            }
        }
        if (targets.isEmpty())
        {
            return 0;
        }
        settingsMapper.deleteStatusLogs(targets);
        return settingsMapper.deleteCandidates(companyId, targets);
    }

    private void recordBackupTime(Long companyId, String time)
    {
        String key = "enterprise.lastBackup." + companyId;
        if (settingsMapper.updateConfigValue(key, time) == 0)
        {
            settingsMapper.insertConfig("企业最近备份时间-公司" + companyId, key, time);
        }
    }

    private String csv(Object v)
    {
        if (v == null)
        {
            return "";
        }
        String s = v.toString().replace("\"", "\"\"");
        return "\"" + s + "\"";
    }

    private String statusText(Object v)
    {
        if (v == null)
        {
            return "未知";
        }
        int s = ((Number) v).intValue();
        // 求职者状态四态收敛：0-已投递、2-待面试、3-已淘汰、4-已录用
        String[] names = { "已投递", "", "待面试", "已淘汰", "已录用" };
        return s >= 0 && s < names.length && !names[s].isEmpty() ? names[s] : String.valueOf(s);
    }

    private String sqlValue(Object v)
    {
        if (v == null)
        {
            return "NULL";
        }
        if (v instanceof Number || v instanceof Boolean)
        {
            return v.toString();
        }
        String s = v.toString();
        if (v instanceof Date)
        {
            s = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format((Date) v);
        }
        StringBuilder sb = new StringBuilder("'");
        for (char c : s.toCharArray())
        {
            if (c == '\'' || c == '\\')
            {
                sb.append('\\');
            }
            if (c == '\n')
            {
                sb.append("\\n");
                continue;
            }
            if (c == '\r')
            {
                continue;
            }
            sb.append(c);
        }
        return sb.append('\'').toString();
    }
}
