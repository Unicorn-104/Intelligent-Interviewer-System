package com.ruoyi.enterprise.service;

import static org.junit.jupiter.api.Assertions.*;

import java.io.Reader;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;

import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.io.Resources;
import org.apache.ibatis.jdbc.ScriptRunner;
import org.apache.ibatis.mapping.Environment;
import org.apache.ibatis.session.Configuration;
import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;
import org.apache.ibatis.transaction.jdbc.JdbcTransactionFactory;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.TestMethodOrder;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import com.ruoyi.common.enums.ApplicationEndReason;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.domain.ProcessStageInstance;
import com.ruoyi.enterprise.mapper.ApplicationStatusMapper;
import com.ruoyi.enterprise.mapper.ProcessStageInstanceMapper;

/**
 * MySQL 8 concurrency integration tests for the application-status state machine
 * and process-stage idempotency.
 *
 * <p>Each worker owns an independent MyBatis SqlSession/JDBC connection. The tests
 * use explicit latches around the real mapper calls so that row-lock contention is
 * deterministic rather than relying only on two threads starting at approximately
 * the same time.</p>
 *
 * <p>Important: scenarios B/C exercise the real ApplicationStatusService state
 * machine, but intentionally do not claim to cover OfferServiceImpl's
 * t_off_offer.updateOfferResult guard or TalStatusService's full aggregate path.
 * Those require additional production tables/mappers and should be a separate
 * service-chain integration test.</p>
 *
 * <p>Scenarios D/E synchronize both transactions at the parent-row lock: the
 * first transaction holds the real <code>SELECT ... FOR UPDATE</code> lock on
 * t_process_instance while the second transaction is blocked on the same row.
 * After the first commits the new node, the second transaction acquires the
 * lock and reads the existing node, so both callbacks return the same node id
 * without any duplicate insert.</p>
 *
 * <p>This class starts a disposable MySQL 8 Testcontainer and creates only its
 * isolated test schema. It never connects to a production database.</p>
 *
 * <pre>
 * mvn -o test -Dtest=ApplicationStatusConcurrencyIT -Dsurefire.failIfNoSpecifiedTests=false
 * </pre>
 */
@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
@TestMethodOrder(MethodOrderer.MethodName.class)
class ApplicationStatusConcurrencyIT {
    private static final long WAIT_SECONDS = 15L;
    private static final long FUTURE_TIMEOUT_SECONDS = 30L;

    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("recruit_it")
            .withUsername("it")
            .withPassword("it")
            .withReuse(false);

    private SqlSessionFactory factory;

    private record Ctx(ApplicationStatusMapper appMapper,
            ProcessStageInstanceMapper stageMapper,
            ApplicationStatusService statusService,
            ProcessStageInstanceService stageService)
    {
    }

    private record Outcome(Object value, Throwable error)
    {
        boolean succeeded()
        {
            return error == null;
        }

        boolean returnedTrue()
        {
            return Boolean.TRUE.equals(value);
        }
    }

    @FunctionalInterface
    private interface TxWork
    {
        Object run(Ctx ctx) throws Exception;
    }

    @FunctionalInterface
    private interface ThrowingCall
    {
        Object call() throws Throwable;
    }

    /** 并发协调器：统一行锁/父锁的等待与释放，所有等待均带超时 */
    private interface LockCoordinator
    {
        void awaitContenders() throws Exception;

        void releaseFirst();
    }

    @BeforeAll
    void initFactory() throws Exception
    {
        UnpooledDataSource dataSource = new UnpooledDataSource("com.mysql.cj.jdbc.Driver",
                MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        Environment environment = new Environment("it", new JdbcTransactionFactory(), dataSource);
        Configuration configuration = new Configuration(environment);
        configuration.setMapUnderscoreToCamelCase(true);

        for (String mapperXml : List.of(
                "mapper/enterprise/ApplicationStatusMapper.xml",
                "mapper/enterprise/ProcessStageInstanceMapper.xml"))
        {
            try (Reader reader = Resources.getResourceAsReader(mapperXml))
            {
                new XMLMapperBuilder(reader, configuration, mapperXml,
                        configuration.getSqlFragments()).parse();
            }
        }
        factory = new SqlSessionFactoryBuilder().build(configuration);

        // DDL is executed only inside the disposable Testcontainers MySQL instance.
        try (SqlSession session = factory.openSession(false);
             Reader schema = Resources.getResourceAsReader("sql/it_schema.sql"))
        {
            ScriptRunner runner = new ScriptRunner(session.getConnection());
            runner.setLogWriter(null);
            runner.setErrorLogWriter(null);
            runner.setAutoCommit(true);
            runner.runScript(schema);
            session.commit();
        }
    }

    // ---------------------------------------------------------------------
    // A. Two HR users terminate the same application concurrently.
    // ---------------------------------------------------------------------
    @Test
    void scenarioA_twoHrTerminateSameApplication_onlyFirstTerminationIsPersisted() throws Exception
    {
        long candidateId = 1001L;
        long positionId = 2001L;
        long processInstanceId = seedInstance(candidateId, positionId);
        long appId = seedApplication(candidateId, positionId, 1, processInstanceId);
        RowLockGate gate = new RowLockGate();

        List<Outcome> outcomes = runParallelAtAppLock(List.of(
                ctx -> ctx.statusService().terminate(appId, ApplicationEndReason.HR_REJECTED,
                        111L, ApplicationStatusService.SOURCE_HR, "HR-111 主动淘汰"),
                ctx -> ctx.statusService().terminate(appId, ApplicationEndReason.HR_REJECTED,
                        112L, ApplicationStatusService.SOURCE_HR, "HR-112 主动淘汰")), gate, false);

        assertEquals(2, outcomes.size());
        assertTrue(outcomes.stream().allMatch(Outcome::returnedTrue),
                "相同终止原因的第二次请求应幂等成功");
        assertEquals(5L, scalar("select app_status from t_app_record where app_id = ?", appId));
        assertEquals("HR_REJECTED", stringScalar(
                "select end_reason from t_app_record where app_id = ?", appId));
        assertEquals(1L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appId),
                "只能产生一条真实状态变更日志");

        long endedBy = scalar("select ended_by from t_app_record where app_id = ?", appId);
        long loggedOperator = scalar(
                "select asl_operator_id from t_app_status_log where asl_app_id = ? limit 1", appId);
        assertTrue(endedBy == 111L || endedBy == 112L);
        assertEquals(loggedOperator, endedBy,
                "幂等重试不能覆盖首次终止操作人");
        assertEquals(3L, scalar("select pin_status from t_process_instance where pin_id = ?", processInstanceId));
    }

    // ---------------------------------------------------------------------
    // B. Offer acceptance and expiration race for the same application.
    // ---------------------------------------------------------------------
    @Test
    void scenarioB_offerAcceptedVsExpired_onlyOneTerminalTransitionWins() throws Exception
    {
        long candidateId = 1002L;
        long positionId = 2002L;
        long processInstanceId = seedInstance(candidateId, positionId);
        long appId = seedApplication(candidateId, positionId, 3, processInstanceId);
        RowLockGate gate = new RowLockGate();

        List<Outcome> outcomes = runParallelAtAppLock(List.of(
                ctx -> ctx.statusService().offerAccepted(appId, 5002L,
                        ApplicationStatusService.SOURCE_OFFER),
                ctx -> ctx.statusService().terminate(appId, ApplicationEndReason.OFFER_EXPIRED,
                        null, ApplicationStatusService.SOURCE_SCHEDULER, "Offer 回复超时")), gate, false);

        assertOnlyOneServiceException(outcomes);
        long finalStatus = scalar("select app_status from t_app_record where app_id = ?", appId);
        assertTrue(finalStatus == 4L || finalStatus == 5L,
                "最终状态只能是已录用(4)或未录用(5)");
        assertEquals(1L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appId));

        if (finalStatus == 4L)
        {
            assertNull(stringScalar("select end_reason from t_app_record where app_id = ?", appId));
            assertEquals(1L, scalar("select pin_status from t_process_instance where pin_id = ?", processInstanceId));
        }
        else
        {
            assertEquals("OFFER_EXPIRED", stringScalar(
                    "select end_reason from t_app_record where app_id = ?", appId));
            assertEquals(3L, scalar("select pin_status from t_process_instance where pin_id = ?", processInstanceId));
        }
    }

    // ---------------------------------------------------------------------
    // C. HR rejection and candidate Offer acceptance race.
    // ---------------------------------------------------------------------
    @Test
    void scenarioC_hrRejectVsOfferAccepted_onlyOneTerminalTransitionWins() throws Exception
    {
        long candidateId = 1003L;
        long positionId = 2003L;
        long processInstanceId = seedInstance(candidateId, positionId);
        long appId = seedApplication(candidateId, positionId, 3, processInstanceId);
        RowLockGate gate = new RowLockGate();

        List<Outcome> outcomes = runParallelAtAppLock(List.of(
                ctx -> ctx.statusService().terminate(appId, ApplicationEndReason.HR_REJECTED,
                        9L, ApplicationStatusService.SOURCE_HR, "HR 复核淘汰"),
                ctx -> ctx.statusService().offerAccepted(appId, 5003L,
                        ApplicationStatusService.SOURCE_OFFER)), gate, false);

        assertOnlyOneServiceException(outcomes);
        long finalStatus = scalar("select app_status from t_app_record where app_id = ?", appId);
        assertTrue(finalStatus == 4L || finalStatus == 5L);
        assertEquals(1L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appId));

        if (finalStatus == 5L)
        {
            assertEquals("HR_REJECTED", stringScalar(
                    "select end_reason from t_app_record where app_id = ?", appId));
            assertEquals(9L, scalar("select ended_by from t_app_record where app_id = ?", appId));
            assertEquals(3L, scalar("select pin_status from t_process_instance where pin_id = ?", processInstanceId));
        }
        else
        {
            assertNull(stringScalar("select end_reason from t_app_record where app_id = ?", appId));
            assertEquals(1L, scalar("select pin_status from t_process_instance where pin_id = ?", processInstanceId));
        }
    }

    // ---------------------------------------------------------------------
    // D. Two concurrent callbacks open/submit the same exam record.
    // The barrier is placed AFTER both SELECTs returned null, exposing the
    // current SELECT-then-INSERT race deterministically.
    // ---------------------------------------------------------------------
    @Test
    void scenarioD_concurrentExamCallbackSameRef_doesNotCreateDuplicateNode() throws Exception
    {
        long candidateId = 1004L;
        long positionId = 2004L;
        long processInstanceId = seedInstance(candidateId, positionId);
        long appId = seedApplication(candidateId, positionId, 1, processInstanceId);
        long examRecordId = 9001L;
        ParentLockGate gate = new ParentLockGate();

        List<Outcome> outcomes = runParallelAtParentLock(List.of(
                ctx -> {
                    ProcessStageInstance node = ctx.stageService().getOrCreate(processInstanceId, null,
                            ProcessStageInstance.TYPE_EXAM, "在线笔试", examRecordId, 11L);
                    ctx.stageService().start(node.getId(), 11L);
                    return node.getId();
                },
                ctx -> {
                    ProcessStageInstance node = ctx.stageService().getOrCreate(processInstanceId, null,
                            ProcessStageInstance.TYPE_EXAM, "在线笔试", examRecordId, 12L);
                    ctx.stageService().start(node.getId(), 12L);
                    return node.getId();
                }), gate);

        assertTrue(outcomes.stream().allMatch(Outcome::succeeded),
                "两个重复笔试回调都应安全完成，而不是靠唯一键异常兜底");
        Long firstNodeId = (Long) outcomes.get(0).value();
        Long secondNodeId = (Long) outcomes.get(1).value();
        assertNotNull(firstNodeId, "首次回调应返回节点ID");
        assertEquals(firstNodeId, secondNodeId, "并发回调必须命中同一流程节点，不得各建一个");
        assertEquals(1L, scalar(
                "select count(*) from t_process_instance_stage where pis_instance_id = ? and pis_node_type = 1 and pis_ref_id = ?",
                processInstanceId, examRecordId),
                "同一笔试记录并发回调只能创建一个流程节点");
        assertEquals(1L, scalar("select count(distinct pis_round) from t_process_instance_stage where pis_instance_id = ? and pis_node_type = 1",
                processInstanceId));
        assertEquals(1L, scalar(
                "select pis_status from t_process_instance_stage where pis_instance_id = ? and pis_node_type = 1 and pis_ref_id = ? limit 1",
                processInstanceId, examRecordId),
                "笔试节点应处于进行中");
        assertEquals(1L, scalar("select app_status from t_app_record where app_id = ?", appId),
                "笔试节点回调不得修改岗位投递整体状态");
        assertEquals(0L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appId));
    }

    // ---------------------------------------------------------------------
    // E. Two concurrent callbacks complete the same interview appointment.
    // ---------------------------------------------------------------------
    @Test
    void scenarioE_concurrentInterviewEndSameRef_doesNotCreateDuplicateNode() throws Exception
    {
        long candidateId = 1005L;
        long positionId = 2005L;
        long processInstanceId = seedInstance(candidateId, positionId);
        long appId = seedApplication(candidateId, positionId, 1, processInstanceId);
        long appointmentId = 9002L;
        ParentLockGate gate = new ParentLockGate();

        List<Outcome> outcomes = runParallelAtParentLock(List.of(
                ctx -> {
                    ProcessStageInstance node = ctx.stageService().getOrCreate(processInstanceId, null,
                            ProcessStageInstance.TYPE_AI_INTERVIEW, "AI 技术面试", appointmentId, 21L);
                    ctx.stageService().start(node.getId(), 21L);
                    ctx.stageService().complete(node.getId(), ProcessStageInstance.RESULT_PASS, "面试通过");
                    return node.getId();
                },
                ctx -> {
                    ProcessStageInstance node = ctx.stageService().getOrCreate(processInstanceId, null,
                            ProcessStageInstance.TYPE_AI_INTERVIEW, "AI 技术面试", appointmentId, 22L);
                    ctx.stageService().start(node.getId(), 22L);
                    ctx.stageService().complete(node.getId(), ProcessStageInstance.RESULT_PASS, "重复回调");
                    return node.getId();
                }), gate);

        assertTrue(outcomes.stream().allMatch(Outcome::succeeded));
        Long firstNodeId = (Long) outcomes.get(0).value();
        Long secondNodeId = (Long) outcomes.get(1).value();
        assertNotNull(firstNodeId);
        assertEquals(firstNodeId, secondNodeId, "并发面试结束回调必须命中同一节点");
        assertEquals(1L, scalar(
                "select count(*) from t_process_instance_stage where pis_instance_id = ? and pis_node_type = 2 and pis_ref_id = ?",
                processInstanceId, appointmentId),
                "同一面试预约并发结束回调只能对应一个流程节点");
        assertEquals(2L, scalar(
                "select pis_status from t_process_instance_stage where pis_instance_id = ? and pis_node_type = 2 and pis_ref_id = ? limit 1",
                processInstanceId, appointmentId));
        assertEquals(1L, scalar(
                "select pis_result from t_process_instance_stage where pis_instance_id = ? and pis_node_type = 2 and pis_ref_id = ? limit 1",
                processInstanceId, appointmentId));
        assertEquals(1L, scalar("select app_status from t_app_record where app_id = ?", appId));
        assertEquals(0L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appId));
    }

    // ---------------------------------------------------------------------
    // F. Same candidate advances two different job applications concurrently.
    // The second row lock must be acquired while the first is still held.
    // ---------------------------------------------------------------------
    @Test
    void scenarioF_sameCandidateDifferentApplications_advanceIndependently() throws Exception
    {
        long candidateId = 1006L;
        long positionOne = 2006L;
        long positionTwo = 2007L;
        long instanceOne = seedInstance(candidateId, positionOne);
        long instanceTwo = seedInstance(candidateId, positionTwo);
        long appOne = seedApplication(candidateId, positionOne, 0, instanceOne);
        long appTwo = seedApplication(candidateId, positionTwo, 0, instanceTwo);
        RowLockGate gate = new RowLockGate();

        List<Outcome> outcomes = runParallelAtAppLock(List.of(
                ctx -> ctx.statusService().startRecruitment(appOne, 31L),
                ctx -> ctx.statusService().startRecruitment(appTwo, 32L)), gate, true);

        assertTrue(outcomes.stream().allMatch(Outcome::returnedTrue));
        assertEquals(1L, scalar("select app_status from t_app_record where app_id = ?", appOne));
        assertEquals(1L, scalar("select app_status from t_app_record where app_id = ?", appTwo));
        assertEquals(1L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appOne));
        assertEquals(1L, scalar("select count(*) from t_app_status_log where asl_app_id = ?", appTwo));
        assertEquals(positionOne, scalar("select app_position_id from t_app_record where app_id = ?", appOne));
        assertEquals(positionTwo, scalar("select app_position_id from t_app_record where app_id = ?", appTwo));
    }

    // =====================================================================
    // Test infrastructure
    // =====================================================================

    private long seedInstance(long candidateId, long positionId) throws Exception
    {
        try (SqlSession session = factory.openSession(false);
             PreparedStatement statement = session.getConnection().prepareStatement(
                     "insert into t_process_instance (pin_candidate_id, pin_position_id) values (?, ?)",
                     Statement.RETURN_GENERATED_KEYS))
        {
            statement.setLong(1, candidateId);
            statement.setLong(2, positionId);
            statement.executeUpdate();
            long id = generatedId(statement);
            session.commit();
            return id;
        }
    }

    private long seedApplication(long candidateId, long positionId, int status, long processInstanceId)
            throws Exception
    {
        try (SqlSession session = factory.openSession(false);
             PreparedStatement statement = session.getConnection().prepareStatement(
                     "insert into t_app_record (app_candidate_id, app_position_id, app_status, "
                             + "app_process_instance_id) values (?, ?, ?, ?)",
                     Statement.RETURN_GENERATED_KEYS))
        {
            statement.setLong(1, candidateId);
            statement.setLong(2, positionId);
            statement.setInt(3, status);
            statement.setLong(4, processInstanceId);
            statement.executeUpdate();
            long id = generatedId(statement);
            session.commit();
            return id;
        }
    }

    private static long generatedId(PreparedStatement statement) throws Exception
    {
        try (ResultSet resultSet = statement.getGeneratedKeys())
        {
            assertTrue(resultSet.next(), "INSERT 应返回自增主键");
            return resultSet.getLong(1);
        }
    }

    private List<Outcome> runParallelAtAppLock(List<TxWork> tasks, RowLockGate gate,
            boolean requireSecondLockAcquired) throws Exception
    {
        gate.requireSecondLockAcquired = requireSecondLockAcquired;
        return runParallel(tasks,
                mapper -> withAppLockGate(mapper, gate),
                Function.identity(), gate);
    }

    private List<Outcome> runParallelAtParentLock(List<TxWork> tasks, ParentLockGate gate)
            throws Exception
    {
        return runParallel(tasks, Function.identity(),
                mapper -> withParentLockGate(mapper, gate), gate);
    }

    private List<Outcome> runParallel(List<TxWork> tasks,
            Function<ApplicationStatusMapper, ApplicationStatusMapper> appMapperDecorator,
            Function<ProcessStageInstanceMapper, ProcessStageInstanceMapper> stageMapperDecorator,
            LockCoordinator lockGate) throws Exception
    {
        int workerCount = tasks.size();
        ExecutorService executor = Executors.newFixedThreadPool(workerCount);
        CountDownLatch ready = new CountDownLatch(workerCount);
        CountDownLatch start = new CountDownLatch(1);
        List<Future<Outcome>> futures = new ArrayList<>();

        try
        {
            for (TxWork task : tasks)
            {
                futures.add(executor.submit(() -> {
                    ready.countDown();
                    if (!start.await(WAIT_SECONDS, TimeUnit.SECONDS))
                        throw new IllegalStateException("并发测试启动屏障超时");
                    return runInTransaction(task, appMapperDecorator, stageMapperDecorator);
                }));
            }

            assertTrue(ready.await(WAIT_SECONDS, TimeUnit.SECONDS), "工作线程未全部就绪");
            start.countDown();

            if (lockGate != null)
            {
                try
                {
                    lockGate.awaitContenders();
                }
                finally
                {
                    lockGate.releaseFirst();
                }
            }

            List<Outcome> outcomes = new ArrayList<>(workerCount);
            for (Future<Outcome> future : futures)
            {
                try
                {
                    outcomes.add(future.get(FUTURE_TIMEOUT_SECONDS, TimeUnit.SECONDS));
                }
                catch (Exception exception)
                {
                    outcomes.add(new Outcome(null, exception));
                }
            }
            return outcomes;
        }
        finally
        {
            start.countDown();
            if (lockGate != null) lockGate.releaseFirst();
            executor.shutdownNow();
            executor.awaitTermination(WAIT_SECONDS, TimeUnit.SECONDS);
        }
    }

    private Outcome runInTransaction(TxWork task,
            Function<ApplicationStatusMapper, ApplicationStatusMapper> appMapperDecorator,
            Function<ProcessStageInstanceMapper, ProcessStageInstanceMapper> stageMapperDecorator)
    {
        try (SqlSession session = factory.openSession(false))
        {
            try
            {
                ApplicationStatusMapper appMapper = appMapperDecorator.apply(
                        session.getMapper(ApplicationStatusMapper.class));
                ProcessStageInstanceMapper stageMapper = stageMapperDecorator.apply(
                        session.getMapper(ProcessStageInstanceMapper.class));
                Ctx context = new Ctx(appMapper, stageMapper,
                        new ApplicationStatusService(appMapper),
                        new ProcessStageInstanceService(stageMapper));
                Object value = task.run(context);
                session.commit();
                return new Outcome(value, null);
            }
            catch (Throwable throwable)
            {
                try
                {
                    session.rollback();
                }
                catch (Throwable rollbackError)
                {
                    throwable.addSuppressed(rollbackError);
                }
                return new Outcome(null, unwrap(throwable));
            }
        }
        catch (Throwable throwable)
        {
            return new Outcome(null, unwrap(throwable));
        }
    }

    private static ApplicationStatusMapper withAppLockGate(ApplicationStatusMapper delegate,
            RowLockGate gate)
    {
        return (ApplicationStatusMapper) Proxy.newProxyInstance(
                ApplicationStatusMapper.class.getClassLoader(),
                new Class<?>[] { ApplicationStatusMapper.class },
                (proxy, method, args) -> {
                    if ("lockAppStatus".equals(method.getName()))
                        return gate.aroundFirstRowLock(() -> invoke(delegate, method, args));
                    return invoke(delegate, method, args);
                });
    }

    private static ProcessStageInstanceMapper withParentLockGate(ProcessStageInstanceMapper delegate,
            ParentLockGate gate)
    {
        return (ProcessStageInstanceMapper) Proxy.newProxyInstance(
                ProcessStageInstanceMapper.class.getClassLoader(),
                new Class<?>[] { ProcessStageInstanceMapper.class },
                (proxy, method, args) -> {
                    if ("lockProcessInstance".equals(method.getName()))
                        return gate.aroundParentLock(() -> invoke(delegate, method, args));
                    return invoke(delegate, method, args);
                });
    }

    private static Object invoke(Object target, Method method, Object[] args) throws Throwable
    {
        try
        {
            return method.invoke(target, args);
        }
        catch (InvocationTargetException exception)
        {
            throw exception.getTargetException();
        }
    }

    private static Throwable unwrap(Throwable throwable)
    {
        Throwable current = throwable;
        while ((current instanceof InvocationTargetException
                || current.getCause() != null && current.getClass().getName().contains("UndeclaredThrowable"))
                && current.getCause() != null)
        {
            current = current.getCause();
        }
        return current;
    }

    private void assertOnlyOneServiceException(List<Outcome> outcomes)
    {
        assertEquals(2, outcomes.size());
        assertEquals(1L, outcomes.stream().filter(Outcome::succeeded).count(),
                "竞争双方只能有一个状态流转成功");
        assertEquals(1L, outcomes.stream().filter(outcome -> outcome.error() instanceof ServiceException).count(),
                "失败方应由状态机终态守卫拒绝");
    }

    private long scalar(String sql, long... parameters) throws Exception
    {
        try (SqlSession session = factory.openSession(true);
             PreparedStatement statement = session.getConnection().prepareStatement(sql))
        {
            for (int i = 0; i < parameters.length; i++) statement.setLong(i + 1, parameters[i]);
            try (ResultSet resultSet = statement.executeQuery())
            {
                assertTrue(resultSet.next(), "标量查询必须返回一行：" + sql);
                return resultSet.getLong(1);
            }
        }
    }

    private String stringScalar(String sql, long... parameters) throws Exception
    {
        try (SqlSession session = factory.openSession(true);
             PreparedStatement statement = session.getConnection().prepareStatement(sql))
        {
            for (int i = 0; i < parameters.length; i++) statement.setLong(i + 1, parameters[i]);
            try (ResultSet resultSet = statement.executeQuery())
            {
                assertTrue(resultSet.next(), "标量查询必须返回一行：" + sql);
                return resultSet.getString(1);
            }
        }
    }

    /**
     * Forces the first transaction to hold the real app row lock while the second
     * transaction has reached the same mapper call. For scenario F, the test also
     * requires the second, different app row lock to be acquired before releasing
     * the first one.
     */
    private static final class RowLockGate implements LockCoordinator
    {
        private final AtomicInteger calls = new AtomicInteger();
        private final CountDownLatch firstLocked = new CountDownLatch(1);
        private final CountDownLatch secondAttempted = new CountDownLatch(1);
        private final CountDownLatch secondAcquired = new CountDownLatch(1);
        private final CountDownLatch release = new CountDownLatch(1);
        private boolean requireSecondLockAcquired;

        Object aroundFirstRowLock(ThrowingCall delegate) throws Throwable
        {
            int call = calls.incrementAndGet();
            if (call == 1)
            {
                Object value = delegate.call(); // SELECT ... FOR UPDATE has acquired the row lock.
                firstLocked.countDown();
                if (!release.await(WAIT_SECONDS, TimeUnit.SECONDS))
                    throw new IllegalStateException("等待释放首个行锁超时");
                return value;
            }
            if (call == 2)
            {
                secondAttempted.countDown();
                // 先确认事务A已真正拿到行锁再尝试，避免角色线程被抢占导致顺序不确定
                if (!firstLocked.await(WAIT_SECONDS, TimeUnit.SECONDS))
                    throw new IllegalStateException("等待首个事务取得行锁超时");
                Object value = delegate.call(); // Same app blocks here; different app should not.
                secondAcquired.countDown();
                return value;
            }
            return delegate.call();
        }

        @Override
        public void awaitContenders() throws InterruptedException
        {
            assertTrue(firstLocked.await(WAIT_SECONDS, TimeUnit.SECONDS), "首个事务未取得行锁");
            assertTrue(secondAttempted.await(WAIT_SECONDS, TimeUnit.SECONDS), "第二个事务未尝试取得行锁");
            if (requireSecondLockAcquired)
            {
                assertTrue(secondAcquired.await(WAIT_SECONDS, TimeUnit.SECONDS),
                        "不同岗位投递的行锁不应互相阻塞");
            }
        }

        @Override
        public void releaseFirst()
        {
            release.countDown();
        }
    }

    /**
     * 父流程实例行锁协调器：事务A取父锁后暂停，事务B尝试同一父锁被真实行锁阻塞；
     * 确认A持锁、B已尝试且未获得后释放A，A建节点提交，B取锁后查到已建节点返回。
     * 两工作线程各自独立 SqlSession/Connection，全程真实 MySQL 行锁，非串行模拟。
     */
    private static final class ParentLockGate implements LockCoordinator
    {
        private final AtomicInteger calls = new AtomicInteger();
        private final CountDownLatch firstLocked = new CountDownLatch(1);
        private final CountDownLatch secondAttempted = new CountDownLatch(1);
        private final CountDownLatch secondAcquired = new CountDownLatch(1);
        private final CountDownLatch release = new CountDownLatch(1);

        Object aroundParentLock(ThrowingCall delegate) throws Throwable
        {
            int call = calls.incrementAndGet();
            if (call == 1)
            {
                Object value = delegate.call(); // 已取得父流程实例行锁
                firstLocked.countDown();
                if (!release.await(WAIT_SECONDS, TimeUnit.SECONDS))
                    throw new IllegalStateException("等待释放父行锁超时");
                return value;
            }
            if (call == 2)
            {
                secondAttempted.countDown();
                // 必须先确认事务A已真正拿到父行锁再尝试，避免角色线程被抢占导致B先得锁
                if (!firstLocked.await(WAIT_SECONDS, TimeUnit.SECONDS))
                    throw new IllegalStateException("等待事务A取得父行锁超时");
                Object value = delegate.call(); // 同一父行在此阻塞，直到事务A提交
                secondAcquired.countDown();
                return value;
            }
            return delegate.call();
        }

        @Override
        public void awaitContenders() throws InterruptedException
        {
            assertTrue(firstLocked.await(WAIT_SECONDS, TimeUnit.SECONDS), "事务A未取得父行锁");
            assertTrue(secondAttempted.await(WAIT_SECONDS, TimeUnit.SECONDS), "事务B未尝试取得父行锁");
            // B 在 A 持锁期间不得获得同一父行锁
            assertFalse(secondAcquired.await(2, TimeUnit.SECONDS),
                    "同一父流程实例行锁应阻塞事务B");
        }

        @Override
        public void releaseFirst()
        {
            release.countDown();
        }
    }
}
