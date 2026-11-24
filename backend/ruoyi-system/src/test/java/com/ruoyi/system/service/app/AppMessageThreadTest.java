package com.ruoyi.system.service.app;

import static org.junit.jupiter.api.Assertions.*;
import java.util.Date;
import java.util.List;
import java.util.Map;
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
import com.ruoyi.system.domain.app.AppMessageThread;
import com.ruoyi.system.mapper.app.AppMessageThreadMapper;
import com.ruoyi.system.service.app.impl.AppMessageThreadService;

/** 真实 Mapper SQL，使用合成通知验证分组、分页、归属及逐批已读。 */
class AppMessageThreadTest
{
    private JdbcTemplate jdbc;
    private AppMessageThreadMapper mapper;
    private AppMessageThreadService service;

    @BeforeEach void setup() throws Exception
    {
        var source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID()
                + ";MODE=MySQL;DB_CLOSE_DELAY=-1", "sa", "");
        jdbc = new JdbcTemplate(source);
        jdbc.execute("create table t_msg(msg_id bigint primary key,msg_receiver_id bigint,msg_type int,"
                + "msg_title varchar(100),msg_content varchar(500),msg_created_at timestamp,"
                + "msg_is_read int,msg_read_at timestamp,msg_target_url varchar(500))");
        jdbc.execute("create table t_cmp(cmp_id bigint primary key,cmp_name varchar(100),cmp_logo_url varchar(200),cmp_status int default 1)");
        jdbc.execute("create table t_usr_interest(int_id bigint primary key,int_user_id bigint,int_target_id bigint,int_target_type int,int_status int,int_created_at timestamp,int_updated_at timestamp)");
        jdbc.execute("create table t_tal(tal_id bigint primary key,tal_user_id bigint)");
        jdbc.execute("create table t_pos(pos_id bigint primary key,pos_company_id bigint,pos_title varchar(100))");
        jdbc.execute("create table t_sch_appointment(apt_id bigint primary key,apt_candidate_id bigint,apt_position_id bigint)");
        jdbc.execute("create table t_sch_reschedule_request(rsr_id bigint primary key,rsr_requester_id bigint,rsr_appointment_id bigint)");
        jdbc.execute("create table sys_user(user_id bigint primary key,nick_name varchar(100),user_name varchar(100),del_flag char,avatar varchar(200))");
        jdbc.execute("create table t_cmp_binding(bnd_user_id bigint,bnd_company_id bigint,bnd_status int)");
        jdbc.execute("create table t_im_session(ims_id bigint primary key,ims_user_a_id bigint,ims_user_b_id bigint,"
                + "ims_last_message varchar(200),ims_last_message_at timestamp,ims_updated_at timestamp,ims_created_at timestamp,ims_unread_b int)");
        jdbc.execute("insert into t_cmp(cmp_id,cmp_name,cmp_logo_url) values(7,'Synthetic A',null),(8,'Synthetic B',null)");
        jdbc.execute("insert into t_pos values(31,7,'Engineer'),(32,7,'Designer')");
        jdbc.execute("insert into t_tal values(21,17),(22,18)");
        jdbc.execute("insert into t_sch_appointment values(11,21,31),(12,21,32),(13,22,31)");
        jdbc.execute("insert into t_sch_reschedule_request values(41,17,11),(42,17,11),(43,18,13)");
        var factory = new SqlSessionFactoryBean();
        factory.setDataSource(source);
        factory.setMapperLocations(new ClassPathResource("mapper/app/AppMessageThreadMapper.xml"));
        mapper = new SqlSessionTemplate(factory.getObject()).getMapper(AppMessageThreadMapper.class);
        service = new AppMessageThreadService();
        ReflectionTestUtils.setField(service, "mapper", mapper);
    }

    private void notify(long id, long user, int type, String target)
    {
        jdbc.update("insert into t_msg values(?,?,?,'Synthetic notice','Synthetic content','2026-11-22 10:00:00',0,null,?)",
                id, user, type, target);
    }

    @SuppressWarnings("unchecked")
    private List<AppMessageThread> items(Map<String, Object> page)
    {
        return (List<AppMessageThread>) page.get("items");
    }

    @Test void reschedulesGroupByAppointmentAndPreserveEveryOriginalEvent()
    {
        notify(1,17,1,"/candidate/interview/appointments/11");
        notify(2,17,1,"/candidate/interview/reschedule-requests/41");
        notify(3,17,1,"/candidate/interview/reschedule-requests/42");
        notify(4,17,1,"/candidate/interview/appointments/12");
        var rows = items(service.threads(17L,"SYSTEM",null,null,20));
        assertEquals(2, rows.size());
        assertEquals(12L, rows.get(0).getThreadId());
        assertEquals(11L, rows.get(1).getThreadId());
        assertEquals(3, rows.get(1).getUnreadCount());
        assertEquals(3, rows.get(1).getMessageCount());
        assertEquals(List.of(3L,2L,1L), items(service.events(17L,"INTERVIEW",11L,null,20))
                .stream().map(AppMessageThread::getSourceId).toList());
        assertEquals(4, jdbc.queryForObject("select count(*) from t_msg", Integer.class));
    }

    @Test void companyFeedKeepsAllPositionsEvenWithoutAnActiveFollowAndPaginates()
    {
        notify(1,17,4,"/companies/7?positionId=31");
        notify(2,17,4,"/companies/7?positionId=32");
        notify(3,17,4,"/companies/8?positionId=33");
        notify(4,18,4,"/companies/7?positionId=34");
        var page = service.threads(17L,"COMPANY",null,null,1);
        assertEquals(true, page.get("hasMore"));
        var first = items(page).get(0);
        assertEquals(8L,first.getThreadId());
        var next = items(service.threads(17L,"COMPANY",first.getOccurredAt(),first.getSourceId(),1));
        assertEquals(7L,next.get(0).getThreadId());
        assertEquals(2,next.get(0).getMessageCount());
        var events = service.events(17L,"COMPANY",7L,null,1);
        assertEquals(true,events.get("hasMore"));
        assertEquals(2L,items(events).get(0).getSourceId());
        assertEquals("/companies/7?positionId=31",items(service.events(17L,"COMPANY",7L,2L,1)).get(0).getTargetUrl());
    }

    @Test void readingOnlyLoadedEventsLeavesOlderAndConcurrentMessagesUnread()
    {
        notify(1,17,4,"/companies/7?positionId=31");
        notify(2,17,4,"/companies/7?positionId=32");
        var loaded = items(service.events(17L,"COMPANY",7L,null,1));
        notify(3,17,4,"/companies/7?positionId=33");
        service.markRead(17L,"COMPANY",7L,loaded.stream().map(AppMessageThread::getSourceId).toList());
        service.markRead(17L,"COMPANY",7L,List.of(2L));
        assertEquals(2,items(service.threads(17L,"COMPANY",null,null,20)).get(0).getUnreadCount());
        assertEquals(0,jdbc.queryForObject("select msg_is_read from t_msg where msg_id=1",Integer.class));
        assertEquals(1,jdbc.queryForObject("select msg_is_read from t_msg where msg_id=2",Integer.class));
        assertEquals(0,jdbc.queryForObject("select msg_is_read from t_msg where msg_id=3",Integer.class));
    }

    @Test void foreignRecordsCannotBeReadOrMarkedAndMissingBusinessLinksRemainSeparate()
    {
        notify(1,18,4,"/companies/7?positionId=31");
        notify(2,17,4,"/companies/8?positionId=32");
        notify(3,17,1,"/candidate/interview/appointments/13");
        notify(4,17,1,null);
        assertTrue(items(service.events(17L,"COMPANY",7L,null,20)).isEmpty());
        assertTrue(items(service.events(17L,"INTERVIEW",13L,null,20)).isEmpty());
        assertThrows(ServiceException.class,()->service.markRead(17L,"COMPANY",7L,List.of(1L,2L)));
        assertEquals(0,jdbc.queryForObject("select sum(msg_is_read) from t_msg",Integer.class));
        var other = items(service.events(17L,"SYSTEM",0L,null,20));
        assertEquals(2,other.size());
        assertEquals(2,items(service.threads(17L,"SYSTEM",null,null,20)).get(0).getUnreadCount());
    }

    @Test void countsIncludeAllCategoriesAndRejectInvalidCursorsOrReadPayloads()
    {
        notify(1,17,1,null);
        notify(2,17,4,"/companies/7?positionId=31");
        jdbc.execute("insert into sys_user values(30,'Recruiter','hr','0',null)");
        jdbc.execute("insert into t_im_session values(9,30,17,'Hello',now(),now(),now(),5)");
        var counts = service.threads(17L,"HR",null,null,20).get("unreadCounts");
        assertEquals(Map.of("HR",5,"COMPANY",1,"SYSTEM",1),counts);
        assertThrows(ServiceException.class,()->service.threads(17L,"BAD",null,null,20));
        assertThrows(ServiceException.class,()->service.threads(17L,"HR",new Date(),null,20));
        assertThrows(ServiceException.class,()->service.events(17L,"SYSTEM",1L,null,20));
        assertThrows(ServiceException.class,()->service.markRead(17L,"SYSTEM",0L,List.of()));
    }

    @Test void absentRescheduleTableDoesNotBreakUnifiedFeedOrHistory()
    {
        jdbc.execute("drop table t_sch_reschedule_request");
        notify(1,17,4,"/companies/7?positionId=31");
        notify(2,17,1,"/candidate/interview/reschedule-requests/41");
        notify(3,17,1,"/candidate/interview/appointments/11");
        jdbc.execute("insert into sys_user values(30,'Recruiter','hr','0',null)");
        jdbc.execute("insert into t_im_session values(9,30,17,'Hello','2026-11-22 11:00:00',now(),now(),1)");
        assertFalse(mapper.hasRescheduleTable());
        var rows = items(service.threads(17L,"ALL",null,null,20));
        assertEquals(List.of("HR","INTERVIEW","SYSTEM","COMPANY"), rows.stream().map(AppMessageThread::getThreadType).toList());
        assertEquals(1,items(service.events(17L,"SYSTEM",0L,null,20)).size());
        assertEquals(1,items(service.events(17L,"INTERVIEW",11L,null,20)).size());
        service.markRead(17L,"SYSTEM",0L,List.of(2L));
        assertEquals(1,jdbc.queryForObject("select msg_is_read from t_msg where msg_id=2",Integer.class));
    }

    @Test void absentInterestTableDoesNotBreakNotificationFeed()
    {
        jdbc.execute("drop table t_usr_interest");
        notify(1,17,1,null);
        assertFalse(mapper.hasInterestTable());
        assertEquals(1, items(service.threads(17L,"ALL",null,null,20)).size());
    }

    @Test void followedCompaniesRemainVisibleWithoutInventingEventsOrUnreadCounts()
    {
        jdbc.execute("insert into t_usr_interest values(100,17,7,2,1,now(),now()),(101,18,8,2,1,now(),now())");
        var rows = items(service.threads(17L,"ALL",null,null,20));
        assertEquals(1,rows.size());
        assertEquals(7L,rows.get(0).getThreadId());
        assertEquals(0,rows.get(0).getMessageCount());
        assertEquals(0,rows.get(0).getUnreadCount());
        assertTrue(items(service.events(17L,"COMPANY",7L,null,20)).isEmpty());
        notify(1,17,4,"/companies/7?positionId=31");
        notify(2,17,4,"/companies/7?positionId=32");
        var published = items(service.threads(17L,"ALL",null,null,20));
        assertEquals(1,published.size());
        assertEquals(2,published.get(0).getMessageCount());
        assertEquals(2,published.get(0).getUnreadCount());
    }

    @Test void unifiedCursorDoesNotSkipSessionsWithSameTimeAndIdAsNotifications()
    {
        notify(9,17,4,"/companies/7?positionId=31");
        jdbc.execute("insert into sys_user values(30,'Recruiter','hr','0',null)");
        jdbc.execute("insert into t_im_session values(9,30,17,'Hello','2026-11-22 10:00:00',now(),now(),1)");
        var first = items(service.threads(17L,"ALL",null,null,null,1)).get(0);
        assertEquals("HR",first.getThreadType());
        var second = items(service.threads(17L,"ALL",first.getOccurredAt(),first.getSourceId(),first.getThreadType(),1)).get(0);
        assertEquals("COMPANY",second.getThreadType());
        assertEquals(9L,second.getSourceId());
    }
}
