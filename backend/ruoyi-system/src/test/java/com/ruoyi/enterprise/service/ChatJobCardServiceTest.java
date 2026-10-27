package com.ruoyi.enterprise.service;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.*;
import java.util.concurrent.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mybatis.spring.SqlSessionFactoryBean;
import org.mybatis.spring.SqlSessionTemplate;
import org.springframework.core.io.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.*;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.transaction.annotation.AnnotationTransactionAttributeSource;
import org.springframework.transaction.interceptor.TransactionInterceptor;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.enterprise.mapper.ChatJobCardMapper;
import com.ruoyi.system.mapper.*;

public class ChatJobCardServiceTest {
 JdbcTemplate db;ChatJobCardService service;ChatJobCardMapper mapper;DashboardMapper companies;
 static final ObjectMapper JSON=new ObjectMapper();
 public static boolean jsonValid(String value){try{return value!=null&&JSON.readTree(value)!=null;}catch(Exception ex){return false;}}
 public static String jsonExtract(String value,String path)throws Exception{if(!jsonValid(value))return null;var field=JSON.readTree(value).get(path.substring(2));return field==null?null:field.toString();}
 public static String jsonUnquote(String value)throws Exception{return value==null?null:JSON.readTree(value).asText();}
 private Resource resource(String name)throws Exception{
  String xml=new ClassPathResource(name).getContentAsString(java.nio.charset.StandardCharsets.UTF_8).replace("sysdate()","current_timestamp");
  for(String side:List.of("a","b")){String col="ims_unread_"+side;
   xml=xml.replace("if(ims_user_"+side+"_id = #{receiverId}, "+col+" + 1, "+col+")","case when ims_user_"+side+"_id = #{receiverId} then "+col+" + 1 else "+col+" end");
   xml=xml.replace("if(ims_user_"+side+"_id = #{userId}, 0, "+col+")","case when ims_user_"+side+"_id = #{userId} then 0 else "+col+" end");}
  return new ByteArrayResource(xml.getBytes(java.nio.charset.StandardCharsets.UTF_8),name);
 }
 @BeforeEach void setup()throws Exception{
  var ds=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=MySQL;DATABASE_TO_UPPER=false;DB_CLOSE_DELAY=-1;LOCK_TIMEOUT=5000","sa","");db=new JdbcTemplate(ds);
  for(var alias:List.of("json_valid:jsonValid","json_extract:jsonExtract","json_unquote:jsonUnquote")){var names=alias.split(":");db.execute("CREATE ALIAS "+names[0]+" FOR 'com.ruoyi.enterprise.service.ChatJobCardServiceTest."+names[1]+"'");}
  for(String sql:List.of(
   "create table sys_user(user_id bigint primary key,nick_name varchar(100),avatar varchar(200),status varchar(1),del_flag varchar(1))",
   "create table t_tal(tal_id bigint primary key,tal_user_id bigint)",
   "create table t_cmp(cmp_id bigint primary key,cmp_name varchar(100),cmp_status int)",
   "create table t_pos(pos_id bigint primary key,pos_company_id bigint,pos_title varchar(100),pos_work_city varchar(100),pos_salary_min decimal,pos_salary_max decimal,pos_experience_required varchar(50),pos_education_required int,pos_status int)",
   "create table t_im_session(ims_id bigint auto_increment primary key,ims_user_a_id bigint,ims_user_b_id bigint,ims_last_message varchar(255),ims_last_message_at timestamp,ims_unread_a int default 0,ims_unread_b int default 0,ims_created_at timestamp,ims_updated_at timestamp)",
   "create table t_im_message(imsg_id bigint auto_increment primary key,imsg_session_id bigint,imsg_sender_id bigint,imsg_type int,imsg_content text,imsg_attachment_url varchar(255),imsg_is_recalled int default 0,imsg_created_at timestamp)",
   "insert into sys_user values(9,'合成HR','','0','0'),(10,'另一HR','','0','0'),(101,'合成求职者','','0','0'),(102,'另一求职者','','0','0')",
   "insert into t_tal values(11,101),(12,102)",
   "insert into t_cmp values(1,'合成企业',1),(2,'其他企业',1)",
   "insert into t_pos values(7,1,'合成在招岗位','杭州',20000,30000,'3年',3,1),(8,2,'他企岗位','上海',10000,20000,'1年',3,1),(9,1,'停招岗位','杭州',10000,20000,'1年',3,0)"))db.execute(sql);
  var factory=new SqlSessionFactoryBean();factory.setDataSource(ds);factory.setTypeAliasesPackage("com.ruoyi.system.domain");
  factory.setMapperLocations(resource("mapper/enterprise/ChatJobCardMapper.xml"),resource("mapper/system/ImMessageMapper.xml"),resource("mapper/system/ImSessionMapper.xml"));
  var template=new SqlSessionTemplate(factory.getObject());mapper=template.getMapper(ChatJobCardMapper.class);
  companies=mock(DashboardMapper.class);when(companies.selectCompanyIdByUser(9L)).thenReturn(1L);when(companies.selectCompanyIdByUser(10L)).thenReturn(2L);
  var target=new ChatJobCardService();ReflectionTestUtils.setField(target,"cards",mapper);ReflectionTestUtils.setField(target,"companies",companies);
  ReflectionTestUtils.setField(target,"messages",template.getMapper(ImMessageMapper.class));ReflectionTestUtils.setField(target,"sessions",template.getMapper(ImSessionMapper.class));
  var proxy=new ProxyFactory(target);proxy.setProxyTargetClass(true);proxy.addAdvice(new TransactionInterceptor(new DataSourceTransactionManager(ds),new AnnotationTransactionAttributeSource()));service=(ChatJobCardService)proxy.getProxy();
 }
 String req="1234567890abcdef12345678";
 @Test void selectionOnlyReturnsOwnActiveJobsAndSupportsSearch(){assertEquals(1,service.jobs(9L,null,1).size());assertTrue(service.jobs(9L,"不存在",1).isEmpty());assertEquals(1,service.jobs(9L,"在招",1).size());assertThrows(ServiceException.class,()->service.jobs(101L,null,1));}
 @Test void sendCreatesRealPeerSessionCardAndCandidateUnread()throws Exception{
  var result=service.send(9L,null,101L,7L,req);var content=JSON.readTree(db.queryForObject("select imsg_content from t_im_message",String.class));
  assertEquals("job_card",content.path("kind").asText());assertEquals(7,content.path("positionId").asLong());assertEquals("合成在招岗位",content.path("title").asText());
  assertEquals(6,db.queryForObject("select imsg_type from t_im_message",Integer.class));assertEquals(9L,db.queryForObject("select imsg_sender_id from t_im_message",Long.class));assertEquals(1,db.queryForObject("select ims_unread_b from t_im_session",Integer.class));assertEquals(0,db.queryForObject("select ims_unread_a from t_im_session",Integer.class));assertNotNull(result.get("messageId"));
 }
 @Test void duplicateRequestIsIdempotentAndCannotChangeJobOrPeer(){var first=service.send(9L,null,101L,7L,req);assertEquals(first,service.send(9L,null,101L,7L,req));assertEquals(1,db.queryForObject("select count(*) from t_im_message",Integer.class));assertThrows(ServiceException.class,()->service.send(9L,null,102L,7L,req));assertThrows(ServiceException.class,()->service.send(9L,null,101L,8L,req));}
 @Test void ownSessionAndPeerMustMatchAndCrossCompanyOrStoppedJobsAreRejected(){
  db.execute("insert into t_im_session(ims_id,ims_user_a_id,ims_user_b_id) values(55,9,101),(56,10,102)");
  assertThrows(ServiceException.class,()->service.send(9L,56L,102L,7L,req));assertThrows(ServiceException.class,()->service.send(9L,55L,102L,7L,req));
  for(long id:List.of(8L,9L,999L))assertThrows(ServiceException.class,()->service.send(9L,55L,101L,id,req));
  assertThrows(ServiceException.class,()->service.send(9L,null,9L,7L,req));assertThrows(ServiceException.class,()->service.send(9L,null,10L,7L,req));
  assertEquals(0,db.queryForObject("select count(*) from t_im_message",Integer.class));
 }
 @Test void messageFailureRollsBackNewSession(){db.execute("alter table t_im_message add constraint reject_card check(imsg_type<>6)");assertThrows(RuntimeException.class,()->service.send(9L,null,101L,7L,req));assertEquals(0,db.queryForObject("select count(*) from t_im_session",Integer.class));}
 @Test void concurrentRetrySendsOnce()throws Exception{var pool=Executors.newFixedThreadPool(2);try{Callable<Map<String,Object>> action=()->service.send(9L,null,101L,7L,req);var results=pool.invokeAll(List.of(action,action));assertEquals(results.get(0).get(),results.get(1).get());}finally{pool.shutdownNow();}assertEquals(1,db.queryForObject("select count(*) from t_im_message",Integer.class));}
 @Test void validatesRequestAndPagination(){assertThrows(ServiceException.class,()->service.send(9L,null,101L,7L,"invalid"));assertThrows(ServiceException.class,()->service.jobs(9L,null,0));assertThrows(ServiceException.class,()->service.send(9L,null,101L,0L,req));}
}
