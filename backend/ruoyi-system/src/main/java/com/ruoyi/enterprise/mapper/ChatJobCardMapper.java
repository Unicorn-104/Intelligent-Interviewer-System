package com.ruoyi.enterprise.mapper;
import java.util.List;
import java.util.Map;
import org.apache.ibatis.annotations.Param;
public interface ChatJobCardMapper {
 Long lockSender(@Param("userId") Long userId);
 List<Map<String,Object>> jobs(@Param("companyId") Long companyId,@Param("keyword") String keyword,@Param("offset") int offset);
 Map<String,Object> job(@Param("companyId") Long companyId,@Param("positionId") Long positionId);
 Long candidateUser(@Param("peerId") Long peerId);
 Map<String,Object> existing(@Param("userId") Long userId,@Param("requestId") String requestId);
}
