package com.ruoyi.framework.web.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;
import com.ruoyi.common.constant.CacheConstants;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.system.service.ISysUserService;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;

/**
 * TokenService 双令牌/版本号/失效机制回归测试（纯 Mockito，不启动容器）
 */
@SuppressWarnings({ "unchecked", "rawtypes" })
public class TokenServiceTest
{
    private static final String SECRET =
            "RegressionTestSecretKeyForHS512RegressionTestSecretKeyForHS512RegressionTestKey0123456789";

    private TokenService tokenService;
    private RedisCache redisCache;
    private RedisTemplate redisTemplate;
    private SetOperations setOperations;
    private ISysUserService userService;
    private SysPermissionService permissionService;

    /** 模拟 redis 的键值存储与集合存储 */
    private final Map<String, Object> cache = new HashMap<>();
    private final Map<String, Set<Object>> setCache = new HashMap<>();

    @BeforeEach
    public void setUp()
    {
        redisCache = mock(RedisCache.class);
        redisTemplate = mock(RedisTemplate.class);
        setOperations = mock(SetOperations.class);
        userService = mock(ISysUserService.class);
        permissionService = mock(SysPermissionService.class);

        redisCache.redisTemplate = redisTemplate;
        when(redisTemplate.opsForSet()).thenReturn(setOperations);

        when(redisCache.getCacheObject(anyString())).thenAnswer(inv -> cache.get(inv.<String>getArgument(0)));
        doAnswer(inv -> {
            cache.put(inv.getArgument(0), inv.getArgument(1));
            return null;
        }).when(redisCache).setCacheObject(anyString(), any());
        doAnswer(inv -> {
            cache.put(inv.getArgument(0), inv.getArgument(1));
            return null;
        }).when(redisCache).setCacheObject(anyString(), any(), anyInt(), any(TimeUnit.class));
        when(redisCache.deleteObject(anyString())).thenAnswer(inv -> cache.remove(inv.<String>getArgument(0)) != null);
        when(redisCache.hasKey(anyString())).thenAnswer(inv -> cache.containsKey(inv.<String>getArgument(0)));
        when(redisCache.getCacheSet(anyString())).thenAnswer(inv -> setCache.get(inv.<String>getArgument(0)));
        when(redisCache.expire(anyString(), anyLong(), any(TimeUnit.class))).thenReturn(true);

        tokenService = new TokenService();
        ReflectionTestUtils.setField(tokenService, "header", "Authorization");
        ReflectionTestUtils.setField(tokenService, "secret", SECRET);
        ReflectionTestUtils.setField(tokenService, "expireTime", 30);
        ReflectionTestUtils.setField(tokenService, "refreshExpireTime", 7);
        ReflectionTestUtils.setField(tokenService, "redisCache", redisCache);
        ReflectionTestUtils.setField(tokenService, "permissionService", permissionService);
        ReflectionTestUtils.setField(tokenService, "userService", userService);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("User-Agent",
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }

    @AfterEach
    public void tearDown()
    {
        RequestContextHolder.resetRequestAttributes();
    }

    private String buildToken(Map<String, Object> claims)
    {
        return Jwts.builder().setClaims(claims).signWith(SignatureAlgorithm.HS512, SECRET).compact();
    }

    private MockHttpServletRequest bearerRequest(String token)
    {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("Authorization", Constants.TOKEN_PREFIX + token);
        return request;
    }

    private LoginUser loginUser(Long userId, String sessionId)
    {
        SysUser user = new SysUser();
        user.setUserId(userId);
        user.setUserName("testuser");
        LoginUser loginUser = new LoginUser(userId, 100L, user, new HashSet<>());
        loginUser.setToken(sessionId);
        return loginUser;
    }

    /**
     * 场景1：令牌版本号与 Redis 中当前版本不一致（如 resetPwd 后），携带旧 ver 的访问令牌失效
     */
    @Test
    public void accessTokenWithStaleVersionIsRejected()
    {
        cache.put(CacheConstants.TOKEN_VERSION_KEY + 1L, 1L);
        cache.put(CacheConstants.LOGIN_TOKEN_KEY + "sess-1", loginUser(1L, "sess-1"));

        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.LOGIN_USER_KEY, "sess-1");
        claims.put(Constants.JWT_JTI, "jti-old");
        claims.put(Constants.JWT_TYPE, Constants.TOKEN_TYPE_ACCESS);
        claims.put(Constants.JWT_VER, 0L);
        String token = buildToken(claims);

        assertNull(tokenService.getLoginUser(bearerRequest(token)), "ver=0 的旧令牌在版本号已递增为 1 后应失效");
    }

    /**
     * 场景2：删除用户 invalidateUserTokens —— 版本号递增且带 7 天 TTL、在线会话与刷新令牌被清理
     */
    @Test
    public void invalidateUserTokensBumpsVersionAndClearsSessions()
    {
        cache.put(CacheConstants.TOKEN_VERSION_KEY + 1L, 0L);
        cache.put(CacheConstants.LOGIN_TOKEN_KEY + "sess-mine", loginUser(1L, "sess-mine"));
        cache.put(CacheConstants.LOGIN_TOKEN_KEY + "sess-other", loginUser(2L, "sess-other"));
        when(redisTemplate.execute(any(RedisCallback.class)))
                .thenReturn(Arrays.asList(CacheConstants.LOGIN_TOKEN_KEY + "sess-mine",
                        CacheConstants.LOGIN_TOKEN_KEY + "sess-other"));

        String indexKey = CacheConstants.USER_REFRESH_KEY + 1L;
        setCache.put(indexKey, new LinkedHashSet<>(Arrays.asList("jti-a")));
        cache.put(CacheConstants.REFRESH_TOKEN_KEY + "jti-a", "1:sess-mine");
        when(setOperations.size(indexKey)).thenReturn(0L);

        tokenService.invalidateUserTokens(1L);

        verify(redisCache).setCacheObject(eq(CacheConstants.TOKEN_VERSION_KEY + 1L), eq(1L), eq(7),
                eq(TimeUnit.DAYS));
        assertEquals(1L, cache.get(CacheConstants.TOKEN_VERSION_KEY + 1L), "令牌版本号应递增为旧值+1");
        assertFalse(cache.containsKey(CacheConstants.LOGIN_TOKEN_KEY + "sess-mine"), "该用户在线会话应被删除");
        assertTrue(cache.containsKey(CacheConstants.LOGIN_TOKEN_KEY + "sess-other"), "其它用户会话不应被误删");
        assertFalse(cache.containsKey(CacheConstants.REFRESH_TOKEN_KEY + "jti-a"), "该用户刷新令牌应被删除");
        verify(setOperations).remove(indexKey, "jti-a");
        assertFalse(cache.containsKey(indexKey), "刷新令牌索引清空后应被删除");
    }

    /**
     * 场景3：不含 ver 声明的旧令牌依赖会话缓存，会话被删除后旧令牌失效
     */
    @Test
    public void legacyTokenWithoutSessionCacheIsRejected()
    {
        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.LOGIN_USER_KEY, "sess-deleted");
        claims.put(Constants.JWT_JTI, "jti-legacy");
        String token = buildToken(claims);

        assertNull(tokenService.getLoginUser(bearerRequest(token)), "会话缓存不存在时旧令牌应失效");
    }

    /**
     * 场景4：刷新令牌一次性轮换 —— 首次使用成功换发新令牌对且旧刷新令牌被删除，重复使用被拒绝
     */
    @Test
    public void refreshTokenIsRotatedAndSingleUse()
    {
        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.JWT_JTI, "jti-r1");
        claims.put(Constants.JWT_USERID, 1L);
        claims.put(Constants.JWT_TYPE, Constants.TOKEN_TYPE_REFRESH);
        claims.put(Constants.JWT_VER, 0L);
        String refreshToken = buildToken(claims);
        cache.put(CacheConstants.REFRESH_TOKEN_KEY + "jti-r1", "1:sess-1");

        SysUser user = new SysUser();
        user.setUserId(1L);
        user.setUserName("testuser");
        user.setStatus("0");
        user.setDelFlag("0");
        when(userService.selectUserById(1L)).thenReturn(user);
        when(permissionService.getMenuPermission(any(SysUser.class))).thenReturn(new HashSet<>());

        Map<String, Object> result = tokenService.refreshAccessToken(refreshToken);

        assertNotNull(result, "有效的刷新令牌应成功换发新令牌对");
        assertNotNull(result.get(Constants.TOKEN), "结果应包含新的访问令牌");
        assertNotNull(result.get(Constants.REFRESH_TOKEN), "结果应包含新的刷新令牌");
        assertFalse(cache.containsKey(CacheConstants.REFRESH_TOKEN_KEY + "jti-r1"), "旧刷新令牌应已被删除");
        assertTrue(cache.keySet().stream().anyMatch(k -> k.startsWith(CacheConstants.REFRESH_TOKEN_KEY)),
                "应签发新的刷新令牌缓存");
        verify(setOperations).remove(CacheConstants.USER_REFRESH_KEY + 1L, "jti-r1");

        Map<String, Object> replay = tokenService.refreshAccessToken(refreshToken);
        assertNull(replay, "同一刷新令牌重复使用应返回 null");
    }

    /**
     * 场景5：强制下线 —— 会话缓存被删除，且仅该会话对应的刷新令牌被清理并从索引移除
     */
    @Test
    public void forceLogoutClearsSessionAndItsRefreshTokens()
    {
        cache.put(CacheConstants.LOGIN_TOKEN_KEY + "sess-1", loginUser(1L, "sess-1"));
        String indexKey = CacheConstants.USER_REFRESH_KEY + 1L;
        setCache.put(indexKey, new LinkedHashSet<>(Arrays.asList("jti-a", "jti-b")));
        cache.put(CacheConstants.REFRESH_TOKEN_KEY + "jti-a", "1:sess-1");
        cache.put(CacheConstants.REFRESH_TOKEN_KEY + "jti-b", "1:sess-2");
        when(setOperations.size(indexKey)).thenReturn(1L);

        tokenService.forceLogout("sess-1");

        assertFalse(cache.containsKey(CacheConstants.LOGIN_TOKEN_KEY + "sess-1"), "会话缓存应被删除");
        assertFalse(cache.containsKey(CacheConstants.REFRESH_TOKEN_KEY + "jti-a"), "该会话的刷新令牌应被删除");
        assertTrue(cache.containsKey(CacheConstants.REFRESH_TOKEN_KEY + "jti-b"), "其它会话的刷新令牌不应被误删");
        verify(setOperations).remove(indexKey, "jti-a");
        verify(redisCache, never()).deleteObject(indexKey);
    }

    /**
     * 场景6：typ=refresh 的令牌不能走访问令牌通道
     */
    @Test
    public void refreshTokenCannotBeUsedAsAccessToken()
    {
        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.LOGIN_USER_KEY, "sess-1");
        claims.put(Constants.JWT_JTI, "jti-r9");
        claims.put(Constants.JWT_TYPE, Constants.TOKEN_TYPE_REFRESH);
        String token = buildToken(claims);

        assertNull(tokenService.getLoginUser(bearerRequest(token)), "刷新令牌不应通过 getLoginUser 认证通道");
    }

    /**
     * 场景7：退出登录仅清理当前会话——会话缓存与该会话的刷新令牌被删除，
     * 该用户其它在线会话的刷新令牌不受影响，访问令牌 jti 进入黑名单
     */
    @Test
    public void logoutClearsOnlyCurrentSessionRefreshTokens()
    {
        cache.put(CacheConstants.LOGIN_TOKEN_KEY + "sess-1", loginUser(1L, "sess-1"));
        String indexKey = CacheConstants.USER_REFRESH_KEY + 1L;
        setCache.put(indexKey, new LinkedHashSet<>(Arrays.asList("jti-a", "jti-b")));
        cache.put(CacheConstants.REFRESH_TOKEN_KEY + "jti-a", "1:sess-1");
        cache.put(CacheConstants.REFRESH_TOKEN_KEY + "jti-b", "1:sess-2");
        when(setOperations.size(indexKey)).thenReturn(1L);

        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.LOGIN_USER_KEY, "sess-1");
        claims.put(Constants.JWT_JTI, "jti-access-1");
        claims.put(Constants.JWT_TYPE, Constants.TOKEN_TYPE_ACCESS);
        String token = buildToken(claims);

        tokenService.logout(bearerRequest(token));

        assertFalse(cache.containsKey(CacheConstants.LOGIN_TOKEN_KEY + "sess-1"), "当前会话缓存应被删除");
        assertFalse(cache.containsKey(CacheConstants.REFRESH_TOKEN_KEY + "jti-a"), "当前会话的刷新令牌应被删除");
        assertTrue(cache.containsKey(CacheConstants.REFRESH_TOKEN_KEY + "jti-b"), "其它会话的刷新令牌不应被误删");
        verify(setOperations).remove(indexKey, "jti-a");
        verify(redisCache, never()).deleteObject(indexKey);
        assertTrue(cache.containsKey(CacheConstants.ACCESS_BLACKLIST_KEY + "jti-access-1"), "访问令牌应进入黑名单");
    }
}
