package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * 面试日程 applicationId 关联（决策1）的真实 MySQL8 验证：
 * 非终态优先、唯一判定、撤回重投不简单取最新、无法唯一确定返回 null。
 * 仅建最小表，不连任何外部库；容器随测试销毁。
 */
@Testcontainers
class InterviewScheduleApplicationLinkIT
{
    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("recruit_link")
            .withUsername("drill")
            .withPassword("drill")
            .withReuse(false);

    /** 预约开始时间：投递须不晚于该时间才纳入关联 */
    private static final LocalDateTime APPOINTMENT_START = LocalDateTime.of(2026, 12, 1, 10, 0);

    @BeforeAll
    static void initSchema() throws Exception
    {
        try (Connection conn = MYSQL.createConnection(""); var st = conn.createStatement())
        {
            st.execute("""
                create table t_app_record (
                    app_id bigint primary key,
                    app_candidate_id bigint not null,
                    app_position_id bigint not null,
                    app_status int not null,
                    app_created_at datetime not null
                )""");
            st.execute("""
                create table t_sch_appointment (
                    apt_id bigint primary key,
                    apt_candidate_id bigint not null,
                    apt_position_id bigint not null,
                    apt_start_time datetime not null
                )""");
        }
    }

    private void insertAppointment(long candidateId, long positionId) throws Exception
    {
        try (Connection conn = MYSQL.createConnection("");
             PreparedStatement ps = conn.prepareStatement(
                     "insert into t_sch_appointment values (?, ?, ?, ?)"))
        {
            ps.setLong(1, candidateId * 10 + positionId);
            ps.setLong(2, candidateId);
            ps.setLong(3, positionId);
            ps.setTimestamp(4, Timestamp.valueOf(APPOINTMENT_START));
            ps.executeUpdate();
        }
    }

    private void insertApplication(long appId, long candidateId, long positionId,
                                   int status, LocalDateTime createdAt) throws Exception
    {
        try (Connection conn = MYSQL.createConnection("");
             PreparedStatement ps = conn.prepareStatement(
                     "insert into t_app_record values (?, ?, ?, ?, ?)"))
        {
            ps.setLong(1, appId);
            ps.setLong(2, candidateId);
            ps.setLong(3, positionId);
            ps.setInt(4, status);
            ps.setTimestamp(5, Timestamp.valueOf(createdAt));
            ps.executeUpdate();
        }
    }

    /**
     * 与 InterviewScheduleMapper.xml 中 applicationId 标量子查询保持同一逻辑：
     * 非终态(不在4,5)恰好1条取该条；非终态0条且总数1条取该条；其余 null。
     */
    private Long resolveApplicationId(long candidateId, long positionId) throws Exception
    {
        String sql = """
            select case
                     when count(case when ar.app_status not in (4, 5) then 1 end) = 1
                       then max(case when ar.app_status not in (4, 5) then ar.app_id end)
                     when count(case when ar.app_status not in (4, 5) then 1 end) = 0
                          and count(*) = 1
                       then max(ar.app_id)
                     else null
                   end
              from t_app_record ar
             where ar.app_candidate_id = ?
               and ar.app_position_id = ?
               and ar.app_created_at <= ?
            """;
        try (Connection conn = MYSQL.createConnection("");
             PreparedStatement ps = conn.prepareStatement(sql))
        {
            ps.setLong(1, candidateId);
            ps.setLong(2, positionId);
            ps.setTimestamp(3, Timestamp.valueOf(APPOINTMENT_START));
            try (ResultSet rs = ps.executeQuery())
            {
                assertTrue(rs.next());
                long value = rs.getLong(1);
                return rs.wasNull() ? null : value;
            }
        }
    }

    @Test void singleActiveApplicationIsLinked() throws Exception
    {
        insertAppointment(11, 30);
        insertApplication(101, 11, 30, 1, LocalDateTime.of(2026, 11, 1, 9, 0));
        assertEquals(101L, resolveApplicationId(11, 30));
    }

    @Test void withdrawAndReapplyLinksTheActiveOneNotSimplyLatest() throws Exception
    {
        insertAppointment(12, 30);
        // 旧投递已终态（撤回/未录用=5），新投递在招（非终态=1）
        insertApplication(102, 12, 30, 5, LocalDateTime.of(2026, 11, 1, 9, 0));
        insertApplication(103, 12, 30, 1, LocalDateTime.of(2026, 11, 10, 9, 0));
        // 非终态恰好1条，绑定在招的新投递，而非按时间取最新的盲目规则
        assertEquals(103L, resolveApplicationId(12, 30));
    }

    @Test void twoActiveApplicationsReturnNull() throws Exception
    {
        insertAppointment(13, 30);
        // 两条都在招（异常重复投递），无法唯一确定
        insertApplication(104, 13, 30, 0, LocalDateTime.of(2026, 11, 1, 9, 0));
        insertApplication(105, 13, 30, 1, LocalDateTime.of(2026, 11, 5, 9, 0));
        assertNull(resolveApplicationId(13, 30));
    }

    @Test void singleTerminalApplicationIsLinked() throws Exception
    {
        insertAppointment(14, 30);
        // 非终态0条且总数恰好1条，允许绑定唯一终态投递
        insertApplication(106, 14, 30, 4, LocalDateTime.of(2026, 11, 1, 9, 0));
        assertEquals(106L, resolveApplicationId(14, 30));
    }

    @Test void twoTerminalApplicationsReturnNull() throws Exception
    {
        insertAppointment(15, 30);
        insertApplication(107, 15, 30, 4, LocalDateTime.of(2026, 11, 1, 9, 0));
        insertApplication(108, 15, 30, 5, LocalDateTime.of(2026, 11, 5, 9, 0));
        assertNull(resolveApplicationId(15, 30));
    }

    @Test void applicationCreatedAfterInterviewIsExcluded() throws Exception
    {
        insertAppointment(16, 30);
        // 投递晚于面试开始，不满足业务时间证据，返回 null
        insertApplication(109, 16, 30, 1, LocalDateTime.of(2026, 12, 5, 9, 0));
        assertNull(resolveApplicationId(16, 30));
    }

    @Test void differentCandidateAndPositionDoNotCrossLink() throws Exception
    {
        insertAppointment(17, 30);
        insertApplication(110, 17, 30, 1, LocalDateTime.of(2026, 11, 1, 9, 0));
        // 另一岗位/候选人的投递不参与本日程关联
        insertApplication(111, 99, 99, 1, LocalDateTime.of(2026, 11, 1, 9, 0));
        // 本日程只绑定自己的投递，不串用 99/99 的 111
        assertEquals(110L, resolveApplicationId(17, 30));
        // 没有任何投递的组合返回 null
        assertNull(resolveApplicationId(88, 88));
    }
}
