package com.ruoyi.system.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.sql.Timestamp;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.test.util.ReflectionTestUtils;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.domain.ImMessage;
import com.ruoyi.system.domain.ImSession;
import com.ruoyi.system.mapper.ImMessageMapper;
import com.ruoyi.system.mapper.ImSessionMapper;

public class ImServiceMessageTest
{
    private JdbcTemplate jdbc;
    private ImMessageMapper mapper;
    private ImSessionMapper sessions;
    private ImServiceImpl service;
    public static String dateFormat(Timestamp time, String pattern)
    {
        return time == null ? null : time.toLocalDateTime().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    }
    @BeforeEach
    void setup() throws Exception
    {
        var source = new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("CREATE ALIAS date_format FOR 'com.ruoyi.system.service.impl.ImServiceMessageTest.dateFormat'");
        jdbc.execute("create table t_msg(msg_id bigint primary key, msg_receiver_id bigint, msg_title varchar(200), msg_content text, msg_type int, msg_is_read int, msg_read_at timestamp, msg_target_url varchar(255), msg_created_at timestamp)");
        jdbc.execute("create table t_im_message(imsg_id bigint auto_increment primary key, imsg_session_id bigint, imsg_sender_id bigint, imsg_type int, imsg_content text, imsg_attachment_url varchar(255), imsg_is_recalled int default 0, imsg_created_at timestamp default current_timestamp)");
        jdbc.execute("insert into t_msg values(1,11,'合成通知一','合成内容',2,0,null,null,'2026-10-18 09:00:00'),(2,12,'其他用户通知','其他内容',1,0,null,null,'2026-10-18 10:00:00'),(3,11,'合成通知二','合成内容二',1,0,null,null,'2026-10-18 11:00:00')");
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setTypeAliases(ImMessage.class);
        // H2 reserves SYSDATE; only adapt the MySQL clock function in this test resource.
        var xml = new ClassPathResource("mapper/system/ImMessageMapper.xml");
        String sql = new String(xml.getInputStream().readAllBytes(), java.nio.charset.StandardCharsets.UTF_8)
                .replace("sysdate()", "current_timestamp");
        factory.setMapperLocations(new org.springframework.core.io.ByteArrayResource(sql.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(ImMessageMapper.class);
        sessions = mock(ImSessionMapper.class);
        service = new ImServiceImpl();
        ReflectionTestUtils.setField(service,"messageMapper",mapper);
        ReflectionTestUtils.setField(service,"sessionMapper",sessions);
    }
    @Test
    void notificationsOnlyReturnCurrentRecipientAndCursorDoesNotRepeat()
    {
        var first = service.selectNotifications(11L,null,1);
        assertEquals(1,first.size());
        assertEquals(3L,((Number)first.get(0).get("messageId")).longValue());
        assertEquals("合成通知二",first.get(0).get("title"));
        var next = service.selectNotifications(11L,3L,1);
        assertEquals(1L,((Number)next.get(0).get("messageId")).longValue());
        assertEquals(2,service.countUnreadNotifications(11L));
    }
    @Test
    void notificationLimitIsBoundedAndScopeAlwaysUsesLoginUser()
    {
        var recording = mock(ImMessageMapper.class);
        ReflectionTestUtils.setField(service,"messageMapper",recording);
        service.selectNotifications(11L,null,999);
        verify(recording).selectNotifications(11L,null,100);
        service.selectNotifications(11L,9L,0);
        verify(recording).selectNotifications(11L,9L,1);
    }
    @Test
    void readingIsIdempotentAndCannotReadAnotherRecipient()
    {
        assertThrows(ServiceException.class,()->service.readNotification(11L,2L));
        service.readNotification(11L,1L);
        service.readNotification(11L,1L);
        assertEquals(1,service.countUnreadNotifications(11L));
        assertEquals(1,service.countUnreadNotifications(12L));
        assertNotNull(jdbc.queryForObject("select msg_read_at from t_msg where msg_id=1",Timestamp.class));
    }
    @Test
    void readAllKeepsOthersUnreadAndDoesNotChangeImReadSemantics()
    {
        assertEquals(2,service.readAllNotifications(11L));
        assertEquals(0,service.countUnreadNotifications(11L));
        assertEquals(1,service.countUnreadNotifications(12L));
        assertEquals(0,service.readAllNotifications(11L));
        verifyNoInteractions(sessions);
    }
    private ImSession session()
    {
        var value=new ImSession();value.setSessionId(8L);value.setUserAId(11L);value.setUserBId(12L);return value;
    }
    @Test
    void sendingUsesAuthenticatedSenderAndUpdatesExistingSummary()
    {
        when(sessions.selectSessionByIdAndUser(8L,11L)).thenReturn(session());
        var message=new ImMessage();message.setSessionId(8L);message.setSenderId(999L);message.setContent("  合成消息  ");
        assertEquals(8L,service.sendMessage(message,11L,null));
        assertEquals(11L,jdbc.queryForObject("select imsg_sender_id from t_im_message",Long.class));
        assertEquals("合成消息",jdbc.queryForObject("select imsg_content from t_im_message",String.class));
        verify(sessions).updateSessionOnSend(8L,"合成消息",12L);
    }
    @Test
    void foreignSessionsEmptyMessagesAndOversizedTextCannotBeWritten()
    {
        var message=new ImMessage();message.setSessionId(8L);message.setContent("合成消息");
        assertThrows(ServiceException.class,()->service.sendMessage(message,99L,null));
        assertThrows(ServiceException.class,()->service.selectMessageList(8L,99L));
        message.setContent("   ");assertThrows(ServiceException.class,()->service.sendMessage(message,11L,null));
        message.setContent("x".repeat(1001));assertThrows(ServiceException.class,()->service.sendMessage(message,11L,null));
        assertEquals(0,jdbc.queryForObject("select count(*) from t_im_message",Integer.class));
    }
    @Test
    void messageHistoryFlagsMineFromLoginAndExcludesRecalledMessages()
    {
        when(sessions.selectSessionByIdAndUser(8L,11L)).thenReturn(session());
        jdbc.execute("insert into t_im_message(imsg_session_id,imsg_sender_id,imsg_type,imsg_content,imsg_is_recalled) values(8,11,1,'我方合成消息',0),(8,12,1,'对方合成消息',0),(8,12,1,'撤回合成消息',1)");
        var list=service.selectMessageList(8L,11L);
        assertEquals(2,list.size());
        assertTrue(list.get(0).getIsMine());assertFalse(list.get(1).getIsMine());
    }
}
