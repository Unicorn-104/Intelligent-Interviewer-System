package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.Executors;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.domain.app.AppChatMessage;
import com.ruoyi.system.mapper.ImSessionMapper;

class ImReadReceiptServiceTest
{
    private JdbcTemplate jdbc;
    private ImReadReceiptService service, target;
    private ImSessionMapper sessions;
    private DriverManagerDataSource ds;
    @BeforeEach void setup() {
        ds = new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=5000","sa","");
        jdbc = new JdbcTemplate(ds);
        jdbc.execute("create table t_im_session(ims_id bigint primary key,ims_user_a_id bigint,ims_user_b_id bigint,ims_unread_a int,ims_unread_b int)");
        jdbc.execute("create table t_im_message(imsg_id bigint primary key,imsg_session_id bigint,imsg_sender_id bigint,imsg_is_recalled int default 0)");
        jdbc.execute("insert into t_im_session values(8,11,12,1,2),(9,21,22,0,1)");
        jdbc.execute("insert into t_im_message values(1,8,11,0),(2,8,12,0),(3,8,11,0),(4,9,21,0),(5,8,12,0)");
        sessions = mock(ImSessionMapper.class);
        when(sessions.selectSessionByIdAndUser(8L,12L)).thenReturn(session());
        target = new ImReadReceiptService();
        ReflectionTestUtils.setField(target,"jdbc",jdbc);
        ReflectionTestUtils.setField(target,"sessions",sessions);
        var factory = new ProxyFactory(target); factory.setProxyTargetClass(true);
        factory.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds),new AnnotationTransactionAttributeSource()));
        service = (ImReadReceiptService)factory.getProxy();
    }
    private void migration() {
        try {
            java.nio.file.Path directory = java.nio.file.Path.of("").toAbsolutePath();
            while (directory != null && !java.nio.file.Files.exists(directory.resolve("backend/doc/migration_im_read_receipts_20261026.sql")))
                directory = directory.getParent();
            assertNotNull(directory);
            String sql = java.nio.file.Files.readString(directory.resolve("backend/doc/migration_im_read_receipts_20261026.sql"))
                    .replaceAll("(?m)^--.*$", "")
                    .replaceAll("COMMENT '[^']*'", "")
                    .replace("ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='单聊消息已读游标'", "").trim();
            jdbc.execute(sql);
            jdbc.execute(sql); // 使用交付脚本验证重复执行，不回填任何历史已读。
        } catch (java.io.IOException ex) { throw new IllegalStateException(ex); }
    }
    private ImSession session() {
        var row=new ImSession();row.setSessionId(8L);row.setUserAId(11L);row.setUserBId(12L);return row;
    }
    private ImMessage message(long id,long sender) {
        var row=new ImMessage();row.setMessageId(id);row.setSenderId(sender);return row;
    }
    @Test void missingMigrationHidesStatusAndAcknowledgmentDoesNotPretendSuccess() {
        var outgoing=message(1,11);
        service.decorate(11L,session(),List.of(outgoing));
        assertNull(outgoing.getDeliveryStatus());
        assertEquals(false,service.acknowledge(12L,8L,3L).get("supported"));
    }
    @Test void deliveredOnlyChangesAfterPeerViewsSameSessionThroughMessageBoundary() {
        migration();
        var first=message(1,11);var next=message(3,11);var incoming=message(2,12);
        service.decorate(11L,session(),List.of(first,next,incoming));
        assertEquals("delivered",first.getDeliveryStatus());assertEquals("received",incoming.getDeliveryStatus());
        service.acknowledge(12L,8L,1L);
        service.decorate(11L,session(),List.of(first,next));
        assertEquals("read",first.getDeliveryStatus());assertEquals("delivered",next.getDeliveryStatus());
        assertEquals(1,jdbc.queryForObject("select ims_unread_b from t_im_session where ims_id=8",Integer.class));
        assertEquals(1,jdbc.queryForObject("select ims_unread_a from t_im_session where ims_id=8",Integer.class));
    }
    @Test void ownReadCannotMarkOwnOutgoingMessagesReadAndCandidateUsesSameCursor() {
        migration();
        service.acknowledge(11L,8L,3L);
        var outgoing=message(3,11);service.decorate(11L,session(),List.of(outgoing));
        assertEquals("delivered",outgoing.getDeliveryStatus());
        var candidateMessage=new AppChatMessage();candidateMessage.setMessageId(2L);candidateMessage.setSenderId(12L);
        service.decorateCandidate(12L,8L,List.of(candidateMessage));
        assertEquals("read",candidateMessage.getDeliveryStatus());
    }
    @Test void foreignSessionMessageAndInvalidIdsCannotCreateReadReceipts() {
        migration();
        assertThrows(ServiceException.class,()->service.acknowledge(99L,8L,1L));
        assertThrows(ServiceException.class,()->service.acknowledge(12L,8L,4L));
        assertThrows(ServiceException.class,()->service.acknowledge(12L,8L,999L));
        assertThrows(ServiceException.class,()->service.acknowledge(12L,8L,0L));
        assertThrows(ServiceException.class,()->service.decorateCandidate(99L,8L,List.of()));
        assertEquals(0,jdbc.queryForObject("select count(*) from t_im_read_cursor",Integer.class));
    }
    @Test void duplicateAndOutOfOrderRequestsNeverRegressOrReadNewArrivals() {
        migration();
        service.acknowledge(12L,8L,3L);service.acknowledge(12L,8L,1L);service.acknowledge(12L,8L,3L);
        jdbc.execute("insert into t_im_message values(6,8,11,0)");
        service.acknowledge(12L,8L,3L);
        assertEquals(3L,jdbc.queryForObject("select irc_last_message_id from t_im_read_cursor",Long.class));
        assertEquals(1,jdbc.queryForObject("select ims_unread_b from t_im_session where ims_id=8",Integer.class));
        var arrival=message(6,11);service.decorate(11L,session(),List.of(arrival));
        assertEquals("delivered",arrival.getDeliveryStatus());
    }
    @Test void clearingUnreadBadgeDoesNotGenerateReadReceipts() {
        migration();
        jdbc.update("update t_im_session set ims_unread_b=0 where ims_id=8");
        var outgoing=message(1,11);service.decorate(11L,session(),List.of(outgoing));
        assertEquals("delivered",outgoing.getDeliveryStatus());
    }
    @Test void concurrentViewingKeepsMaximumCursor() throws Exception {
        migration();var pool=Executors.newFixedThreadPool(2);
        try {
            Callable<Void> older=()->{service.acknowledge(12L,8L,1L);return null;};
            Callable<Void> newer=()->{service.acknowledge(12L,8L,3L);return null;};
            for(var task:pool.invokeAll(List.of(older,newer)))task.get();
        } finally {pool.shutdownNow();}
        assertEquals(3L,jdbc.queryForObject("select irc_last_message_id from t_im_read_cursor",Long.class));
    }
}
