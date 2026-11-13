package com.ruoyi.enterprise.service;

import java.lang.reflect.Proxy;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import org.apache.ibatis.session.SqlSessionFactory;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.mapper.MapperFactoryBean;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.support.AbstractApplicationContext;
import org.springframework.context.support.PropertySourcesPlaceholderConfigurer;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.OfferMapper;
import com.ruoyi.enterprise.mapper.TalentPoolMapper;
import com.ruoyi.enterprise.mapper.TalStatusMapper;
import com.ruoyi.enterprise.service.impl.OfferServiceImpl;
import com.ruoyi.enterprise.service.impl.TalentPoolServiceImpl;
import com.ruoyi.enterprise.util.MailCredentialCipher;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.ResumePdfProperties;
import com.ruoyi.system.mapper.DashboardMapper;
import com.ruoyi.system.mapper.app.AppResumeMapper;
import com.ruoyi.system.service.EmailService;
import com.ruoyi.system.service.IEnterpriseJobService;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Offer 完整业务链并发集成测试：在真实 Spring 事务代理下，经生产 OfferServiceImpl、
 * TalentPoolServiceImpl 等真实入口竞争，验证 Offer / 投递 / 全局人才状态的一致性。
 *
 * <p>与 ApplicationStatusConcurrencyIT 不同，本类所有 Service 均为 Spring 管理 Bean，
 * 经 {@code @EnableTransactionManagement} 生成事务代理；每个并发线程在独立连接上运行
 * 真实事务，不使用 Mockito 替代核心 Mapper，也不直接调用 Mapper 代替 Service。</p>
 *
 * <p>本类启动一次性 MySQL 8 Testcontainer，仅在该容器内执行 offer_it_schema.sql，
 * 不连接任何生产/远程/本地持久化数据库。</p>
 */
@Testcontainers
class OfferServiceConcurrencyIT
{
    private static final long WAIT_SECONDS = 30L;

    /** 固定测试口径（企业 1、岗位 100/200、候选人 10） */
    private static final long COMPANY_ID = 1L;
    private static final long USER_ID = 1L;
    private static final long CANDIDATE_ID = 10L;
    private static final long POSITION_1 = 100L;
    private static final long POSITION_2 = 200L;

    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("recruit_offer_it").withUsername("it").withPassword("it").withReuse(false);

    private static AbstractApplicationContext spring;
    private JdbcTemplate jdbc;
    private IOfferService offerService;
    private ITalentPoolService talentPoolService;

    /** 一次并发调用的结果（成功或异常） */
    private record Outcome(Throwable error)
    {
        boolean succeeded() { return error == null; }
    }

    @FunctionalInterface
    private interface Action
    {
        void run() throws Exception;
    }

    @BeforeAll
    static void startSpring() throws Exception
    {
        AnnotationConfigApplicationContext ctx = new AnnotationConfigApplicationContext();
        ctx.register(OfferTestConfig.class);
        ctx.refresh();
        spring = ctx;
        // DDL 仅在一次性 Testcontainer 内执行，不连接任何持久化库
        org.springframework.jdbc.datasource.init.ResourceDatabasePopulator populator =
                new org.springframework.jdbc.datasource.init.ResourceDatabasePopulator(
                        new ClassPathResource("sql/offer_it_schema.sql"));
        populator.execute(ctx.getBean(javax.sql.DataSource.class));
    }

    @AfterAll
    static void stopSpring()
    {
        if (spring != null) spring.close();
    }

    @BeforeEach
    void setUp()
    {
        jdbc = spring.getBean(JdbcTemplate.class);
        offerService = spring.getBean(IOfferService.class);
        talentPoolService = spring.getBean(ITalentPoolService.class);
    }

    // ------------------------------------------------------------------
    // A. 接受 Offer vs 过期收口（同一 Offer，真实并发）
    // ------------------------------------------------------------------
    @Test
    void scenarioA_offerAcceptedVsExpired_fullServiceChain() throws Exception
    {
        seedSinglePosition(3, 10, 0, true);
        long offerId = jdbc.queryForObject("select ofr_id from t_off_offer where ofr_candidate_id=? and ofr_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_1);

        AtomicReference<Throwable> acceptErr = new AtomicReference<>();
        Outcome expire = runConcurrent(
                () -> { try { offerService.acceptOffer(USER_ID, offerId); } catch (Exception e) { acceptErr.set(e); } },
                () -> offerService.expireOverdueOffers());
        Outcome accept = new Outcome(acceptErr.get());

        int offerStatus = jdbc.queryForObject("select ofr_status from t_off_offer where ofr_id=?", Integer.class, offerId);
        int appStatus = jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1);
        int talStatus = jdbc.queryForObject("select tal_status from t_tal where tal_id=?", Integer.class, CANDIDATE_ID);
        int appLogs = count("t_app_status_log", "asl_app_id", appId(CANDIDATE_ID, POSITION_1));
        int talLogs = count("t_tal_status_log", "tsl_candidate_id", CANDIDATE_ID);

        // 仅一个终态，Offer 与投递状态一致
        if (offerStatus == 1)
        {
            // 接受胜出：过期扫描返回 0（无异常），接受成功
            trace("A winner=ACCEPT ofr=1 app=" + appStatus + " tal=" + talStatus);
            assertEquals(4, appStatus, "接受 Offer 后投递应为已录用");
            assertEquals(4, talStatus, "接受 Offer 后全局人才状态应为已录用");
            assertTrue(accept.succeeded(), "接受方应成功");
            assertTrue(expire.succeeded(), "过期扫描在 Offer 已被接受时应正常返回 0");
        }
        else
        {
            // 过期胜出：Offer=3，接受方抛 ServiceException 并整体回滚
            trace("A winner=EXPIRE ofr=3 app=" + appStatus + " tal=" + talStatus);
            assertEquals(3, offerStatus, "过期胜出 Offer 应为已过期");
            assertEquals(5, appStatus, "过期后投递应为未录用");
            assertEquals(3, talStatus, "过期后全局人才状态应为已淘汰");
            assertFalse(accept.succeeded(), "接受方应在 Offer 过期后失败");
            assertEquals("OFFER_EXPIRED",
                    jdbc.queryForObject("select end_reason from t_app_record where app_candidate_id=? and app_position_id=?",
                            String.class, CANDIDATE_ID, POSITION_1));
        }
        assertEquals(1, appLogs, "投递状态日志应仅一条，无终态覆盖");
        assertEquals(1, talLogs, "全局人才状态日志应仅一条");
    }

    // ------------------------------------------------------------------
    // B. HR 淘汰 vs 接受 Offer（真实 HR 入口，非状态机直调）
    // ------------------------------------------------------------------
    @Test
    void scenarioB_hrRejectVsOfferAccepted_fullServiceChain() throws Exception
    {
        seedSinglePosition(3, 10, 0, false);
        long offerId = jdbc.queryForObject("select ofr_id from t_off_offer where ofr_candidate_id=? and ofr_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_1);

        AtomicReference<Throwable> hrErr = new AtomicReference<>();
        AtomicReference<Throwable> acceptErr = new AtomicReference<>();
        Outcome both = runConcurrent(
                () -> { try { talentPoolService.terminateApplication(USER_ID, CANDIDATE_ID, POSITION_1, "HR_REJECTED"); }
                        catch (Exception e) { hrErr.set(e); } },
                () -> { try { offerService.acceptOffer(USER_ID, offerId); } catch (Exception e) { acceptErr.set(e); } });

        int appStatus = jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1);
        int offerStatus = jdbc.queryForObject("select ofr_status from t_off_offer where ofr_id=?", Integer.class, offerId);
        int appLogs = count("t_app_status_log", "asl_app_id", appId(CANDIDATE_ID, POSITION_1));

        assertEquals(1, appLogs, "投递状态日志应仅一条，无终态覆盖");
        if (appStatus == 5)
        {
            // HR 淘汰胜出：接受方在终态拦截后整体回滚（Offer 回到已发送 0）
            trace("B winner=HR_REJECT ofr=" + offerStatus + " app=5");
            assertEquals("HR_REJECTED", jdbc.queryForObject(
                    "select end_reason from t_app_record where app_candidate_id=? and app_position_id=?",
                    String.class, CANDIDATE_ID, POSITION_1));
            assertEquals(USER_ID, jdbc.queryForObject(
                    "select ended_by from t_app_record where app_candidate_id=? and app_position_id=?",
                    Long.class, CANDIDATE_ID, POSITION_1));
            assertTrue(hrErr.get() == null, "HR 淘汰方应成功");
            assertNotNull(acceptErr.get(), "接受方应在终态后失败并回滚");
            // 真实行为：terminateApplication 不取消 Offer，接受方回滚后 Offer 仍为已发送(0)
            assertEquals(0, offerStatus, "接受方回滚后 Offer 应恢复为已发送；terminateApplication 本身不改 Offer");
        }
        else
        {
            // 接受胜出：HR 终止在终态被拦截，无 end_reason
            trace("B winner=ACCEPT ofr=" + offerStatus + " app=4");
            assertEquals(4, appStatus, "接受胜出投递应为已录用");
            assertEquals(1, offerStatus, "接受胜出 Offer 应为已接受");
            assertNull(jdbc.queryForObject(
                    "select end_reason from t_app_record where app_candidate_id=? and app_position_id=?",
                    String.class, CANDIDATE_ID, POSITION_1));
            assertTrue(acceptErr.get() == null, "接受方应成功");
            assertNotNull(hrErr.get(), "HR 淘汰方应在终态后失败");
        }
    }

    // ------------------------------------------------------------------
    // B2. HR 淘汰后再次接受 Offer：终态守卫拒绝，且不得覆盖终态/日志/Offer
    // ------------------------------------------------------------------
    @Test
    void scenarioB2_acceptAfterHrReject_terminalGuardRejectsAndNoOverwrite() throws Exception
    {
        // 与 B 同口径：app=3 待确认、tal=10 待发Offer、offer=0 已发送
        seedSinglePosition(3, 10, 0, false);
        long offerId = jdbc.queryForObject("select ofr_id from t_off_offer where ofr_candidate_id=? and ofr_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_1);

        // 1) 真实 HR 入口淘汰（生产链确认：terminateApplication 不取消 Offer）
        talentPoolService.terminateApplication(USER_ID, CANDIDATE_ID, POSITION_1, "HR_REJECTED");
        assertEquals(5, jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1), "HR 淘汰后投递应为未录用");
        assertEquals(0, jdbc.queryForObject("select ofr_status from t_off_offer where ofr_id=?", Integer.class, offerId),
                "terminateApplication 不取消 Offer，Offer 应仍为已发送");

        long applicationId = appId(CANDIDATE_ID, POSITION_1);
        int appLogsBefore = count("t_app_status_log", "asl_app_id", applicationId);
        int talLogsBefore = count("t_tal_status_log", "tsl_candidate_id", CANDIDATE_ID);
        int offerBefore = jdbc.queryForObject("select ofr_status from t_off_offer where ofr_id=?", Integer.class, offerId);
        int talBefore = jdbc.queryForObject("select tal_status from t_tal where tal_id=?", Integer.class, CANDIDATE_ID);

        // 2) 再次以同一 offerId 调真实 acceptOffer：requireSentOffer(offer=0) 与 updateOfferResult 可过，
        //    TalStatusService.change 在同事务内推进并返回 true，但最终 ApplicationStatusService 终态守卫拒绝
        AtomicReference<Throwable> err = new AtomicReference<>();
        try { offerService.acceptOffer(USER_ID, offerId); }
        catch (Throwable t) { err.set(t); }

        Throwable thrown = err.get();
        assertNotNull(thrown, "终态后再次接受必须失败");
        assertTrue(thrown instanceof ServiceException, "失败类型应为 ServiceException，实际：" + thrown.getClass());
        assertTrue(thrown.getMessage() != null && thrown.getMessage().contains("终态"),
                "应在 ApplicationStatusService 终态守卫被拒绝，实际信息：" + thrown.getMessage());

        // 3) 失败整体回滚：终态、end_reason、操作人不被覆盖
        assertEquals(5, jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1), "失败调用不得覆盖终态");
        assertEquals("HR_REJECTED", jdbc.queryForObject(
                "select end_reason from t_app_record where app_candidate_id=? and app_position_id=?",
                String.class, CANDIDATE_ID, POSITION_1), "end_reason 应保持 HR_REJECTED");
        assertEquals(USER_ID, jdbc.queryForObject(
                "select ended_by from t_app_record where app_candidate_id=? and app_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_1), "ended_by 应保持 HR 操作人");

        // 4) 日志不增加（无重复日志）
        assertEquals(appLogsBefore, count("t_app_status_log", "asl_app_id", applicationId),
                "失败调用不得新增投递状态日志");
        assertEquals(talLogsBefore, count("t_tal_status_log", "tsl_candidate_id", CANDIDATE_ID),
                "失败调用内的 tal 日志随回滚撤销，不得新增");

        // 5) Offer 与 tal 均恢复调用前值（同事务回滚）
        assertEquals(offerBefore, jdbc.queryForObject("select ofr_status from t_off_offer where ofr_id=?",
                Integer.class, offerId), "失败调用不得改写 Offer 状态");
        assertEquals(talBefore, jdbc.queryForObject("select tal_status from t_tal where tal_id=?",
                Integer.class, CANDIDATE_ID), "失败调用内的 tal 推进随回滚撤销");
        trace("B2 terminalGuard rejected; rolled back ofr=" + offerBefore + " tal=" + talBefore
                + " appLogs=" + appLogsBefore + " talLogs=" + talLogsBefore);
    }

    // ------------------------------------------------------------------
    // C. 多岗位 TalStatus 聚合：A 接受不翻转全局态、不影响 B
    // ------------------------------------------------------------------
    @Test
    void scenarioC_multiApplicationTalStatusAggregation() throws Exception
    {
        seedTwoPositions();
        long offer1 = jdbc.queryForObject("select ofr_id from t_off_offer where ofr_candidate_id=? and ofr_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_1);

        // 阶段一：岗位 A 接受，岗位 B 仍招聘中 → 全局 tal_status 被聚合守卫拦截
        offerService.acceptOffer(USER_ID, offer1);

        int app1 = jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1);
        int app2 = jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_2);
        int talStatus = jdbc.queryForObject("select tal_status from t_tal where tal_id=?", Integer.class, CANDIDATE_ID);
        int pin1 = jdbc.queryForObject("select pin_status from t_process_instance where pin_candidate_id=? and pin_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1);
        int pin2 = jdbc.queryForObject("select pin_status from t_process_instance where pin_candidate_id=? and pin_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_2);

        assertEquals(4, app1, "岗位 A 应为已录用");
        assertEquals(1, app2, "岗位 B 应保持招聘中，不被覆盖");
        assertNotTerminal(talStatus, "其他岗位活跃时全局人才状态不应翻转为终态");
        assertEquals(1, pin1, "岗位 A 流程实例应完成");
        assertEquals(0, pin2, "岗位 B 流程实例不应被收尾");
        assertEquals(1, count("t_tal_status_log", "tsl_candidate_id", CANDIDATE_ID),
                "聚合守卫应只写一条受保护日志，不重复");
        trace("C phase1 app1=" + app1 + " app2=" + app2 + " tal=" + talStatus + " pin1=" + pin1 + " pin2=" + pin2);

        // 阶段二：岗位 B 也过期，无活跃投递后全局态才按规则翻转
        long offer2 = jdbc.queryForObject("select ofr_id from t_off_offer where ofr_candidate_id=? and ofr_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_2);
        jdbc.update("update t_off_offer set ofr_deadline=date_sub(now(), interval 1 hour) where ofr_id=?", offer2);
        int expired = offerService.expireOverdueOffers();
        assertTrue(expired >= 1, "岗位 B Offer 应被过期收口");
        int finalTal = jdbc.queryForObject("select tal_status from t_tal where tal_id=?", Integer.class, CANDIDATE_ID);
        int finalApp2 = jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_2);
        assertEquals(5, finalApp2, "岗位 B 应已过期为未录用");
        assertEquals(3, finalTal, "无活跃投递后全局态按真实设计翻转（本数据链为已淘汰）");
        trace("C phase2 finalApp2=" + finalApp2 + " finalTal=" + finalTal);
    }

    // ------------------------------------------------------------------
    // D. Offer 更新与状态收口在同一事务，业务守卫失败时整体回滚
    // ------------------------------------------------------------------
    @Test
    void scenarioD_offerAndApplicationRollbackConsistency() throws Exception
    {
        // 候选人已淘汰(3)，不在 acceptOffer 允许来源 [10,2]，change 返回 false
        seedSinglePosition(3, 3, 0, false);
        long offerId = jdbc.queryForObject("select ofr_id from t_off_offer where ofr_candidate_id=? and ofr_position_id=?",
                Long.class, CANDIDATE_ID, POSITION_1);

        AtomicReference<Throwable> err = new AtomicReference<>();
        try { offerService.acceptOffer(USER_ID, offerId); }
        catch (Exception e) { err.set(e); }
        assertNotNull(err.get(), "业务守卫应拒绝并抛异常");

        int offerStatus = jdbc.queryForObject("select ofr_status from t_off_offer where ofr_id=?", Integer.class, offerId);
        int appStatus = jdbc.queryForObject("select app_status from t_app_record where app_candidate_id=? and app_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1);
        assertEquals(0, offerStatus, "回滚后 Offer 应恢复为已发送");
        assertEquals(3, appStatus, "回滚后投递状态应保持待确认 Offer");
        assertEquals(0, count("t_app_status_log", "asl_app_id", appId(CANDIDATE_ID, POSITION_1)),
                "回滚后不应有投递状态日志");
        assertEquals(0, count("t_tal_status_log", "tsl_candidate_id", CANDIDATE_ID),
                "回滚后不应有全局人才状态日志");
        assertEquals(0, jdbc.queryForObject(
                "select pin_status from t_process_instance where pin_candidate_id=? and pin_position_id=?",
                Integer.class, CANDIDATE_ID, POSITION_1), "流程实例应保持原状");
        trace("D guard rejected; rolled back ofr=" + offerStatus + " app=" + appStatus + " appLogs=0 talLogs=0");
    }

    // ============================ 测试数据 ============================

    /** 单岗位：投递状态、tal 状态、Offer 状态；deadlinePast 决定 Offer 是否过期 */
    private void seedSinglePosition(int appStatus, int talStatus, int offerStatus, boolean deadlinePast)
    {
        truncateAll();
        jdbc.update("insert into t_pos (pos_id, pos_title, pos_company_id) values (?, ?, ?)",
                POSITION_1, "后端工程师", COMPANY_ID);
        jdbc.update("insert into t_tal (tal_id, tal_user_id, tal_company_id, tal_status) values (?, ?, ?, ?)",
                CANDIDATE_ID, null, COMPANY_ID, talStatus);
        jdbc.update("insert into t_process_instance (pin_candidate_id, pin_position_id, pin_status) values (?, ?, 0)",
                CANDIDATE_ID, POSITION_1);
        jdbc.update("insert into t_app_record (app_candidate_id, app_position_id, app_status, app_process_instance_id) "
                + "values (?, ?, ?, null)", CANDIDATE_ID, POSITION_1, appStatus);
        String deadline = deadlinePast ? "date_sub(now(), interval 1 hour)" : "date_add(now(), interval 1 day)";
        jdbc.update("insert into t_off_offer (ofr_candidate_id, ofr_position_id, ofr_status, ofr_deadline) "
                + "values (?, ?, ?, " + deadline + ")", CANDIDATE_ID, POSITION_1, offerStatus);
    }

    /** 两岗位：A 待确认 Offer(3)，B 招聘中(1)，全局 tal=2 面试中 */
    private void seedTwoPositions()
    {
        truncateAll();
        jdbc.update("insert into t_pos (pos_id, pos_title, pos_company_id) values (?, ?, ?)",
                POSITION_1, "后端工程师", COMPANY_ID);
        jdbc.update("insert into t_pos (pos_id, pos_title, pos_company_id) values (?, ?, ?)",
                POSITION_2, "算法工程师", COMPANY_ID);
        jdbc.update("insert into t_tal (tal_id, tal_user_id, tal_company_id, tal_status) values (?, ?, ?, 2)",
                CANDIDATE_ID, null, COMPANY_ID);
        jdbc.update("insert into t_process_instance (pin_candidate_id, pin_position_id, pin_status) values (?, ?, 0)",
                CANDIDATE_ID, POSITION_1);
        jdbc.update("insert into t_process_instance (pin_candidate_id, pin_position_id, pin_status) values (?, ?, 0)",
                CANDIDATE_ID, POSITION_2);
        jdbc.update("insert into t_app_record (app_candidate_id, app_position_id, app_status) values (?, ?, 3)",
                CANDIDATE_ID, POSITION_1);
        jdbc.update("insert into t_app_record (app_candidate_id, app_position_id, app_status) values (?, ?, 1)",
                CANDIDATE_ID, POSITION_2);
        jdbc.update("insert into t_off_offer (ofr_candidate_id, ofr_position_id, ofr_status, ofr_deadline) "
                + "values (?, ?, 0, date_add(now(), interval 1 day))", CANDIDATE_ID, POSITION_1);
        jdbc.update("insert into t_off_offer (ofr_candidate_id, ofr_position_id, ofr_status, ofr_deadline) "
                + "values (?, ?, 0, date_add(now(), interval 1 day))", CANDIDATE_ID, POSITION_2);
    }

    private void truncateAll()
    {
        for (String t : List.of("t_msg", "t_tal_status_log", "t_app_status_log", "t_process_instance_stage",
                "t_off_offer", "t_cmp_binding", "t_cmp", "t_process_instance", "t_app_record", "sys_user", "t_pos",
                "t_tal"))
        {
            jdbc.execute("delete from " + t);
        }
    }

    // ============================ 工具方法 ============================

    private Long appId(long candidateId, long positionId)
    {
        return jdbc.queryForObject("select app_id from t_app_record where app_candidate_id=? and app_position_id=?",
                Long.class, candidateId, positionId);
    }

    private int count(String table, String column, Object value)
    {
        Integer n = jdbc.queryForObject("select count(*) from " + table + " where " + column + "=?", Integer.class, value);
        return n == null ? 0 : n;
    }

    /** 仅诊断输出：打印每场景实际胜出/终态，便于核对，不参与任何断言 */
    private static void trace(String message)
    {
        System.out.println("[IT-TRACE] " + message);
    }

    private static void assertNotTerminal(int talStatus, String message)
    {
        assertTrue(talStatus != 3 && talStatus != 4, message + "（实际 tal_status=" + talStatus + "）");
    }

    /** 两动作经同一发令闸真并发，返回任一异常（各自异常在调用处用独立引用捕获） */
    private Outcome runConcurrent(Action a, Action b) throws Exception
    {
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        AtomicReference<Throwable> any = new AtomicReference<>();
        ExecutorService pool = Executors.newFixedThreadPool(2);
        pool.submit(() -> { ready.countDown(); try { start.await(WAIT_SECONDS, TimeUnit.SECONDS); a.run(); }
                catch (Throwable t) { any.set(t); } });
        pool.submit(() -> { ready.countDown(); try { start.await(WAIT_SECONDS, TimeUnit.SECONDS); b.run(); }
                catch (Throwable t) { any.set(t); } });
        assertTrue(ready.await(WAIT_SECONDS, TimeUnit.SECONDS), "并发线程未就绪");
        start.countDown();
        pool.shutdown();
        assertTrue(pool.awaitTermination(WAIT_SECONDS, TimeUnit.SECONDS), "并发任务未在超时内完成");
        return new Outcome(any.get());
    }

    // ============================ Spring 配置 ============================

    @Configuration
    @EnableTransactionManagement
    static class OfferTestConfig
    {
        @Bean
        DriverManagerDataSource dataSource()
        {
            return new DriverManagerDataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        }

        @Bean
        PlatformTransactionManager transactionManager(DriverManagerDataSource ds)
        {
            return new DataSourceTransactionManager(ds);
        }

        @Bean
        JdbcTemplate jdbcTemplate(DriverManagerDataSource ds)
        {
            return new JdbcTemplate(ds);
        }

        @Bean
        SqlSessionFactory sqlSessionFactory(DriverManagerDataSource ds) throws Exception
        {
            org.apache.ibatis.session.Configuration ibatisCfg = new org.apache.ibatis.session.Configuration();
            ibatisCfg.setMapUnderscoreToCamelCase(true);
            SqlSessionFactoryBean fb = new SqlSessionFactoryBean();
            fb.setDataSource(ds);
            fb.setConfiguration(ibatisCfg);
            fb.setMapperLocations(
                    new ClassPathResource("mapper/enterprise/OfferMapper.xml"),
                    new ClassPathResource("mapper/enterprise/ApplicationStatusMapper.xml"),
                    new ClassPathResource("mapper/enterprise/TalStatusMapper.xml"));
            return fb.getObject();
        }

        @Bean
        MapperFactoryBean<OfferMapper> offerMapper(SqlSessionFactory f)
        {
            MapperFactoryBean<OfferMapper> b = new MapperFactoryBean<>(OfferMapper.class);
            b.setSqlSessionFactory(f);
            return b;
        }

        @Bean
        MapperFactoryBean<ApplicationStatusMapper> applicationStatusMapper(SqlSessionFactory f)
        {
            MapperFactoryBean<ApplicationStatusMapper> b = new MapperFactoryBean<>(ApplicationStatusMapper.class);
            b.setSqlSessionFactory(f);
            return b;
        }

        @Bean
        MapperFactoryBean<TalStatusMapper> talStatusMapper(SqlSessionFactory f)
        {
            MapperFactoryBean<TalStatusMapper> b = new MapperFactoryBean<>(TalStatusMapper.class);
            b.setSqlSessionFactory(f);
            return b;
        }

        @Bean
        ApplicationStatusService applicationStatusService(ApplicationStatusMapper m)
        {
            return new ApplicationStatusService(m);
        }

        @Bean
        TalStatusService talStatusService(TalStatusMapper m)
        {
            return new TalStatusService(m);
        }

        @Bean
        MailCredentialCipher mailCredentialCipher()
        {
            return new MailCredentialCipher();
        }

        @Bean
        JavaMailSender javaMailSender()
        {
            return new JavaMailSenderImpl();
        }

        @Bean
        EmailService emailService()
        {
            // mailSender 由 Spring 按类型注入，from 由 spring.mail.username 占位符解析（见 propertyPlaceholder）
            return new EmailService();
        }

        @Bean
        ResumePdfStorage resumePdfStorage()
        {
            return new ResumePdfStorage(new ResumePdfProperties());
        }

        @Bean
        TalentPoolMapper talentPoolMapper()
        {
            return interfaceStub(TalentPoolMapper.class);
        }

        @Bean
        DashboardMapper dashboardMapper()
        {
            return interfaceStub(DashboardMapper.class);
        }

        @Bean
        IScreeningService screeningService()
        {
            return interfaceStub(IScreeningService.class);
        }

        @Bean
        IEnterpriseJobService enterpriseJobService()
        {
            return interfaceStub(IEnterpriseJobService.class);
        }

        @Bean
        AppResumeMapper appResumeMapper()
        {
            return interfaceStub(AppResumeMapper.class);
        }

        @Bean
        OfferServiceImpl offerService()
        {
            return new OfferServiceImpl();
        }

        @Bean
        TalentPoolServiceImpl talentPoolService()
        {
            return new TalentPoolServiceImpl();
        }

        @Bean
        static PropertySourcesPlaceholderConfigurer propertyPlaceholder()
        {
            // 提供 EmailService 所需占位符；本测试不触发真实发信，仅保证上下文可解析
            java.util.Properties props = new java.util.Properties();
            props.setProperty("spring.mail.username", "it@example.com");
            PropertySourcesPlaceholderConfigurer configurer = new PropertySourcesPlaceholderConfigurer();
            configurer.setProperties(props);
            return configurer;
        }
    }

    /** 为非核心路径的接口依赖提供零值动态代理（不替代任何核心 Mapper） */
    @SuppressWarnings("unchecked")
    private static <T> T interfaceStub(Class<T> type)
    {
        return (T) Proxy.newProxyInstance(type.getClassLoader(), new Class<?>[] { type }, (proxy, method, args) ->
        {
            if (method.getName().equals("hashCode")) return System.identityHashCode(proxy);
            if (method.getName().equals("equals")) return proxy == args[0];
            if (method.getName().equals("toString")) return type.getSimpleName() + "#stub";
            Class<?> rt = method.getReturnType();
            if (!rt.isPrimitive()) return null;
            if (rt.equals(boolean.class)) return false;
            if (rt.equals(int.class)) return 0;
            if (rt.equals(long.class)) return 0L;
            if (rt.equals(short.class)) return (short) 0;
            if (rt.equals(byte.class)) return (byte) 0;
            if (rt.equals(char.class)) return (char) 0;
            if (rt.equals(float.class)) return 0f;
            if (rt.equals(double.class)) return 0d;
            return null;
        });
    }
}
