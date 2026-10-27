package com.ruoyi.web.controller.enterprise;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.utils.SecurityUtils;
import com.ruoyi.enterprise.service.ChatJobCardService;
class ChatJobCardControllerTest {
 @Test void selectionAndSendingUseAuthenticatedRecruiterAndServerSnapshot()throws Exception{
  var service=mock(ChatJobCardService.class);var controller=new ChatJobCardController();ReflectionTestUtils.setField(controller,"cards",service);
  when(service.jobs(9L,"合成",2)).thenReturn(List.of(Map.of("positionId",7L,"title","合成岗位")));
  String request="1234567890abcdef12345678";
  when(service.send(9L,8L,101L,7L,request)).thenReturn(Map.of("sessionId",8L,"messageId",71L,"requestId",request));
  try(var auth=mockStatic(SecurityUtils.class)){
   var login=new LoginUser();login.setUserId(9L);auth.when(SecurityUtils::getLoginUser).thenReturn(login);
   var mvc=MockMvcBuilders.standaloneSetup(controller).build();
   mvc.perform(get("/enterprise/chat/jobs").param("keyword","合成").param("page","2").param("companyId","999"))
    .andExpect(status().isOk()).andExpect(jsonPath("$.data[0].positionId").value(7));
   mvc.perform(post("/enterprise/chat/job-cards").contentType("application/json")
     .content("{\"sessionId\":8,\"peerId\":101,\"positionId\":7,\"requestId\":\""+request+"\",\"senderId\":999,\"title\":\"伪造标题不采信\"}"))
    .andExpect(status().isOk()).andExpect(jsonPath("$.data.messageId").value(71));
   verify(service).jobs(9L,"合成",2);verify(service).send(9L,8L,101L,7L,request);
  }
 }
}
