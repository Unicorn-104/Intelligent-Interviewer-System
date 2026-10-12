package com.ruoyi.framework.web.service;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.Cursor;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.ScanOptions;
import org.springframework.stereotype.Component;
import com.ruoyi.common.constant.CacheConstants;
import com.ruoyi.common.constant.Constants;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.core.redis.RedisCache;
import com.ruoyi.common.enums.UserStatus;
import com.ruoyi.common.utils.ServletUtils;
import com.ruoyi.common.utils.StringUtils;
import com.ruoyi.common.utils.http.UserAgentUtils;
import com.ruoyi.common.utils.ip.AddressUtils;
import com.ruoyi.common.utils.ip.IpUtils;
import com.ruoyi.common.utils.uuid.IdUtils;
import com.ruoyi.system.service.ISysUserService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import jakarta.servlet.http.HttpServletRequest;

/**
 * token验证处理
 * 
 * @author ruoyi
 */
@Component
public class TokenService
{
    private static final Logger log = LoggerFactory.getLogger(TokenService.class);

    // 令牌自定义标识
    @Value("${token.header}")
    private String header;

    // 令牌秘钥
    @Value("${token.secret}")
    private String secret;

    // 令牌有效期（默认30分钟）
    @Value("${token.expireTime}")
    private int expireTime;

    // 刷新令牌有效期（默认7天）
    @Value("${token.refreshExpireTime:7}")
    private int refreshExpireTime;

    protected static final long MILLIS_SECOND = 1000;

    protected static final long MILLIS_MINUTE = 60 * MILLIS_SECOND;

    protected static final long MILLIS_DAY = 24 * 60 * MILLIS_MINUTE;

    private static final Long MILLIS_MINUTE_TWENTY = 20 * 60 * 1000L;

    @Autowired
    private RedisCache redisCache;

    @Autowired
    private SysPermissionService permissionService;

    @Autowired
    private ISysUserService userService;

    /**
     * 获取用户身份信息
     * 
     * @return 用户信息
     */
    public LoginUser getLoginUser(HttpServletRequest request)
    {
        // 获取请求携带的令牌
        String token = getToken(request);
        if (StringUtils.isNotEmpty(token))
        {
            try
            {
                Claims claims = parseToken(token);
                // 仅接受访问令牌（兼容不含 typ 声明的旧令牌）
                String type = (String) claims.get(Constants.JWT_TYPE);
                if (StringUtils.isNotEmpty(type) && !Constants.TOKEN_TYPE_ACCESS.equals(type))
                {
                    return null;
                }
                // 已登出的访问令牌不再放行
                String jti = (String) claims.get(Constants.JWT_JTI);
                if (StringUtils.isNotEmpty(jti)
                        && redisCache.hasKey(CacheConstants.ACCESS_BLACKLIST_KEY + jti))
                {
                    return null;
                }
                // 解析对应的权限以及用户信息
                String uuid = (String) claims.get(Constants.LOGIN_USER_KEY);
                String userKey = getTokenKey(uuid);
                LoginUser user = redisCache.getCacheObject(userKey);
                // 令牌版本号与当前用户版本号不一致说明已被批量失效（兼容不含 ver 声明的旧令牌）
                if (user != null && claims.get(Constants.JWT_VER) != null
                        && ((Number) claims.get(Constants.JWT_VER)).longValue() != getTokenVersion(user.getUserId()))
                {
                    return null;
                }
                return user;
            }
            catch (Exception e)
            {
                log.error("获取用户信息异常'{}'", e.getMessage());
            }
        }
        return null;
    }

    /**
     * 设置用户身份信息
     */
    public void setLoginUser(LoginUser loginUser)
    {
        if (StringUtils.isNotNull(loginUser) && StringUtils.isNotEmpty(loginUser.getToken()))
        {
            refreshToken(loginUser);
        }
    }

    /**
     * 删除用户身份信息
     */
    public void delLoginUser(String token)
    {
        if (StringUtils.isNotEmpty(token))
        {
            String userKey = getTokenKey(token);
            redisCache.deleteObject(userKey);
        }
    }

    /**
     * 基于访问令牌构建令牌对结果：访问令牌、访问令牌过期时间、刷新令牌、刷新令牌过期时间
     *
     * @param accessToken 访问令牌
     * @return 令牌对信息
     */
    public Map<String, Object> createTokenPair(String accessToken)
    {
        Map<String, Object> result = new HashMap<>();
        result.put(Constants.TOKEN, accessToken);
        result.put(Constants.TOKEN_EXPIRE_AT, System.currentTimeMillis() + expireTime * MILLIS_MINUTE);
        Map<String, Object> refresh = issueRefreshToken(accessToken);
        if (refresh != null)
        {
            result.putAll(refresh);
        }
        return result;
    }

    /**
     * 签发刷新令牌，刷新令牌一次性使用，redis 记录 refresh:{jti} -> userId:sessionId
     *
     * @param accessToken 访问令牌
     * @return 刷新令牌信息，访问令牌无效时返回 null
     */
    public Map<String, Object> issueRefreshToken(String accessToken)
    {
        LoginUser loginUser;
        String sessionId;
        try
        {
            Claims claims = parseToken(accessToken);
            sessionId = (String) claims.get(Constants.LOGIN_USER_KEY);
            loginUser = redisCache.getCacheObject(getTokenKey(sessionId));
        }
        catch (Exception e)
        {
            log.error("签发刷新令牌失败'{}'", e.getMessage());
            return null;
        }
        if (loginUser == null || loginUser.getUserId() == null)
        {
            return null;
        }
        Long userId = loginUser.getUserId();
        String jti = IdUtils.fastUUID();
        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.JWT_JTI, jti);
        claims.put(Constants.JWT_USERID, userId);
        claims.put(Constants.JWT_TYPE, Constants.TOKEN_TYPE_REFRESH);
        claims.put(Constants.JWT_VER, getTokenVersion(userId));

        redisCache.setCacheObject(CacheConstants.REFRESH_TOKEN_KEY + jti, userId + ":" + sessionId,
                refreshExpireTime, TimeUnit.DAYS);
        redisCache.redisTemplate.opsForSet().add(CacheConstants.USER_REFRESH_KEY + userId, jti);
        redisCache.expire(CacheConstants.USER_REFRESH_KEY + userId, refreshExpireTime, TimeUnit.DAYS);

        Map<String, Object> result = new HashMap<>();
        result.put(Constants.REFRESH_TOKEN, createToken(claims));
        result.put(Constants.REFRESH_EXPIRE_AT, System.currentTimeMillis() + refreshExpireTime * MILLIS_DAY);
        return result;
    }

    /**
     * 使用刷新令牌换取新的访问令牌与刷新令牌，刷新令牌一次性使用
     *
     * @param refreshToken 刷新令牌
     * @return 新令牌对信息，刷新令牌无效时返回 null
     */
    public Map<String, Object> refreshAccessToken(String refreshToken)
    {
        Claims claims;
        try
        {
            claims = parseToken(refreshToken);
        }
        catch (Exception e)
        {
            log.error("刷新令牌解析失败'{}'", e.getMessage());
            return null;
        }
        if (!Constants.TOKEN_TYPE_REFRESH.equals(claims.get(Constants.JWT_TYPE)))
        {
            return null;
        }
        String jti = (String) claims.get(Constants.JWT_JTI);
        String refreshKey = CacheConstants.REFRESH_TOKEN_KEY + jti;
        String value = redisCache.getCacheObject(refreshKey);
        if (StringUtils.isEmpty(value))
        {
            // 已使用或已过期
            return null;
        }
        Long userId = Long.valueOf(value.contains(":") ? value.substring(0, value.indexOf(':')) : value);
        // 一次性使用，先失效再校验
        redisCache.deleteObject(refreshKey);
        redisCache.redisTemplate.opsForSet().remove(CacheConstants.USER_REFRESH_KEY + userId, jti);
        if (claims.get(Constants.JWT_VER) != null
                && ((Number) claims.get(Constants.JWT_VER)).longValue() != getTokenVersion(userId))
        {
            return null;
        }
        SysUser user = userService.selectUserById(userId);
        if (user == null || UserStatus.DISABLE.getCode().equals(user.getStatus())
                || UserStatus.DELETED.getCode().equals(user.getDelFlag()))
        {
            return null;
        }
        // 会话缓存可能已过期，按最新用户信息重建登录态
        LoginUser loginUser = new LoginUser(user.getUserId(), user.getDeptId(), user,
                permissionService.getMenuPermission(user));
        return createTokenPair(createToken(loginUser));
    }

    /**
     * 退出登录：访问令牌加入黑名单，删除当前会话缓存与该会话的刷新令牌（不影响该用户其它在线设备）
     *
     * @param request 请求
     */
    public void logout(HttpServletRequest request)
    {
        String token = getToken(request);
        if (StringUtils.isEmpty(token))
        {
            return;
        }
        LoginUser loginUser = getLoginUser(request);
        if (loginUser != null)
        {
            delLoginUser(loginUser.getToken());
            clearSessionRefreshTokens(loginUser.getUserId(), loginUser.getToken());
        }
        try
        {
            Claims claims = parseToken(token);
            String jti = (String) claims.get(Constants.JWT_JTI);
            if (StringUtils.isNotEmpty(jti))
            {
                redisCache.setCacheObject(CacheConstants.ACCESS_BLACKLIST_KEY + jti, 1, expireTime,
                        TimeUnit.MINUTES);
            }
        }
        catch (Exception e)
        {
            log.error("退出登录处理令牌失败'{}'", e.getMessage());
        }
    }

    /**
     * 获取用户当前令牌版本号，不存在时视为 0
     *
     * @param userId 用户ID
     * @return 令牌版本号
     */
    public long getTokenVersion(Long userId)
    {
        if (userId == null)
        {
            return 0L;
        }
        Object value = redisCache.getCacheObject(CacheConstants.TOKEN_VERSION_KEY + userId);
        return value == null ? 0L : Long.parseLong(value.toString());
    }

    /**
     * 递增用户令牌版本号，使其已签发的全部令牌立即失效
     *
     * @param userId 用户ID
     * @return 新的令牌版本号
     */
    public long incrementTokenVersion(Long userId)
    {
        long next = getTokenVersion(userId) + 1;
        redisCache.setCacheObject(CacheConstants.TOKEN_VERSION_KEY + userId, next);
        return next;
    }

    /**
     * 用户被删除时清理其全部登录态：递增令牌版本号（带 TTL，到期自动清理不留孤儿键）、
     * 删除在线会话缓存与全部刷新令牌，确保已签发的访问令牌立即失效。
     * 注意不能只删除版本键——旧令牌 ver 可能为 0，键删除后 getTokenVersion 回落为 0 仍会校验通过
     *
     * @param userId 用户ID
     */
    public void invalidateUserTokens(Long userId)
    {
        if (userId == null)
        {
            return;
        }
        // 递增版本号并保留足够长的有效期：携带旧版本号（含 0）的令牌立即失效，键到期后自动清理
        long next = getTokenVersion(userId) + 1;
        redisCache.setCacheObject(CacheConstants.TOKEN_VERSION_KEY + userId, next, refreshExpireTime, TimeUnit.DAYS);
        // 删除该用户全部在线会话与刷新令牌（不含 ver 声明的旧令牌依赖会话缓存，删除后同样失效）
        clearOtherSessions(userId, null);
    }

    /**
     * 清除指定会话的刷新令牌（不影响该用户其它会话），索引清空后同步删除索引键
     *
     * @param userId    用户ID
     * @param sessionId 会话标识，即访问令牌中的 login_user_key
     */
    private void clearSessionRefreshTokens(Long userId, String sessionId)
    {
        if (userId == null || StringUtils.isEmpty(sessionId))
        {
            return;
        }
        String indexKey = CacheConstants.USER_REFRESH_KEY + userId;
        Set<Object> jtis = redisCache.getCacheSet(indexKey);
        if (jtis != null)
        {
            String suffix = ":" + sessionId;
            for (Object jti : new ArrayList<>(jtis))
            {
                Object value = redisCache.getCacheObject(CacheConstants.REFRESH_TOKEN_KEY + jti);
                if (value != null && value.toString().endsWith(suffix))
                {
                    redisCache.deleteObject(CacheConstants.REFRESH_TOKEN_KEY + jti);
                    redisCache.redisTemplate.opsForSet().remove(indexKey, jti);
                }
            }
        }
        Long remaining = redisCache.redisTemplate.opsForSet().size(indexKey);
        if (remaining == null || remaining == 0L)
        {
            redisCache.deleteObject(indexKey);
        }
    }

    /**
     * 清除指定用户除当前会话外的其它登录会话及其刷新令牌
     *
     * @param userId           用户ID
     * @param currentSessionId 需保留的会话标识
     */
    public void clearOtherSessions(Long userId, String currentSessionId)
    {
        if (userId == null)
        {
            return;
        }
        // 清理其它会话的登录缓存
        Collection<String> keys = scanKeys(CacheConstants.LOGIN_TOKEN_KEY + "*");
        if (keys != null)
        {
            for (String key : keys)
            {
                LoginUser loginUser = redisCache.getCacheObject(key);
                if (loginUser == null || !userId.equals(loginUser.getUserId()))
                {
                    continue;
                }
                if (StringUtils.isNotEmpty(currentSessionId) && currentSessionId.equals(loginUser.getToken()))
                {
                    continue;
                }
                redisCache.deleteObject(key);
            }
        }
        // 清理其它会话的刷新令牌
        String indexKey = CacheConstants.USER_REFRESH_KEY + userId;
        Set<Object> jtis = redisCache.getCacheSet(indexKey);
        if (jtis != null)
        {
            String suffix = ":" + currentSessionId;
            for (Object jti : new ArrayList<>(jtis))
            {
                Object value = redisCache.getCacheObject(CacheConstants.REFRESH_TOKEN_KEY + jti);
                if (value != null && StringUtils.isNotEmpty(currentSessionId) && value.toString().endsWith(suffix))
                {
                    continue;
                }
                redisCache.deleteObject(CacheConstants.REFRESH_TOKEN_KEY + jti);
                redisCache.redisTemplate.opsForSet().remove(indexKey, jti);
            }
        }
        Long remaining = redisCache.redisTemplate.opsForSet().size(indexKey);
        if (remaining == null || remaining == 0L)
        {
            redisCache.deleteObject(indexKey);
        }
    }

    /**
     * 强制下线指定会话：删除会话缓存并清理该会话的刷新令牌，
     * 避免被强退的客户端通过刷新令牌静默恢复登录
     *
     * @param sessionId 会话标识，即访问令牌中的 login_user_key
     */
    public void forceLogout(String sessionId)
    {
        if (StringUtils.isEmpty(sessionId))
        {
            return;
        }
        String userKey = getTokenKey(sessionId);
        LoginUser loginUser = redisCache.getCacheObject(userKey);
        redisCache.deleteObject(userKey);
        if (loginUser == null || loginUser.getUserId() == null)
        {
            return;
        }
        String indexKey = CacheConstants.USER_REFRESH_KEY + loginUser.getUserId();
        Set<Object> jtis = redisCache.getCacheSet(indexKey);
        if (jtis != null)
        {
            String suffix = ":" + sessionId;
            for (Object jti : new ArrayList<>(jtis))
            {
                Object value = redisCache.getCacheObject(CacheConstants.REFRESH_TOKEN_KEY + jti);
                if (value != null && value.toString().endsWith(suffix))
                {
                    redisCache.deleteObject(CacheConstants.REFRESH_TOKEN_KEY + jti);
                    redisCache.redisTemplate.opsForSet().remove(indexKey, jti);
                }
            }
        }
        Long remaining = redisCache.redisTemplate.opsForSet().size(indexKey);
        if (remaining == null || remaining == 0L)
        {
            redisCache.deleteObject(indexKey);
        }
    }

    /**
     * 创建令牌
     * 
     * @param loginUser 用户信息
     * @return 令牌
     */
    public String createToken(LoginUser loginUser)
    {
        String token = IdUtils.fastUUID();
        loginUser.setToken(token);
        setUserAgent(loginUser);
        refreshToken(loginUser);

        Map<String, Object> claims = new HashMap<>();
        claims.put(Constants.LOGIN_USER_KEY, token);
        claims.put(Constants.JWT_USERNAME, loginUser.getUsername());
        claims.put(Constants.JWT_JTI, IdUtils.fastUUID());
        claims.put(Constants.JWT_TYPE, Constants.TOKEN_TYPE_ACCESS);
        claims.put(Constants.JWT_VER, getTokenVersion(loginUser.getUserId()));
        return createToken(claims);
    }

    /**
     * 验证令牌有效期，相差不足20分钟，自动刷新缓存
     * 
     * @param loginUser 登录信息
     * @return 令牌
     */
    public void verifyToken(LoginUser loginUser)
    {
        long expireTime = loginUser.getExpireTime();
        long currentTime = System.currentTimeMillis();
        if (expireTime - currentTime <= MILLIS_MINUTE_TWENTY)
        {
            refreshToken(loginUser);
        }
    }

    /**
     * 刷新令牌有效期
     * 
     * @param loginUser 登录信息
     */
    public void refreshToken(LoginUser loginUser)
    {
        loginUser.setLoginTime(System.currentTimeMillis());
        loginUser.setExpireTime(loginUser.getLoginTime() + expireTime * MILLIS_MINUTE);
        // 根据uuid将loginUser缓存
        String userKey = getTokenKey(loginUser.getToken());
        redisCache.setCacheObject(userKey, loginUser, expireTime, TimeUnit.MINUTES);
    }

    /**
     * 设置用户代理信息
     * 
     * @param loginUser 登录信息
     */
    public void setUserAgent(LoginUser loginUser)
    {
        String userAgent = ServletUtils.getRequest().getHeader("User-Agent");
        String ip = IpUtils.getIpAddr();
        loginUser.setIpaddr(ip);
        loginUser.setLoginLocation(AddressUtils.getRealAddressByIP(ip));
        loginUser.setBrowser(UserAgentUtils.getBrowser(userAgent));
        loginUser.setOs(UserAgentUtils.getOperatingSystem(userAgent));
    }

    /**
     * 从数据声明生成令牌
     *
     * @param claims 数据声明
     * @return 令牌
     */
    private String createToken(Map<String, Object> claims)
    {
        String token = Jwts.builder()
                .setClaims(claims)
                .signWith(SignatureAlgorithm.HS512, secret).compact();
        return token;
    }

    /**
     * 从令牌中获取数据声明
     *
     * @param token 令牌
     * @return 数据声明
     */
    private Claims parseToken(String token)
    {
        return Jwts.parser()
                .setSigningKey(secret)
                .parseClaimsJws(token)
                .getBody();
    }

    /**
     * 从令牌中获取用户名
     *
     * @param token 令牌
     * @return 用户名
     */
    public String getUsernameFromToken(String token)
    {
        Claims claims = parseToken(token);
        return claims.getSubject();
    }

    /**
     * 获取请求token
     *
     * @param request
     * @return token
     */
    private String getToken(HttpServletRequest request)
    {
        String token = request.getHeader(header);
        if (StringUtils.isNotEmpty(token) && token.startsWith(Constants.TOKEN_PREFIX))
        {
            token = token.replace(Constants.TOKEN_PREFIX, "");
        }
        return token;
    }

    private String getTokenKey(String uuid)
    {
        return CacheConstants.LOGIN_TOKEN_KEY + uuid;
    }

    /**
     * 以 SCAN 游标方式按模式匹配键名，替代 KEYS 命令，避免大键空间下阻塞 Redis
     *
     * @param pattern 键名匹配模式
     * @return 匹配的键名集合
     */
    @SuppressWarnings("unchecked")
    private Collection<String> scanKeys(String pattern)
    {
        return (Collection<String>) redisCache.redisTemplate.execute((RedisCallback<Collection<String>>) connection ->
        {
            Collection<String> keys = new ArrayList<>();
            ScanOptions options = ScanOptions.scanOptions().match(pattern).count(500).build();
            try (Cursor<byte[]> cursor = connection.keyCommands().scan(options))
            {
                while (cursor.hasNext())
                {
                    keys.add(new String(cursor.next(), StandardCharsets.UTF_8));
                }
            }
            catch (Exception e)
            {
                log.error("SCAN 扫描键失败'{}'", e.getMessage());
            }
            return keys;
        });
    }

    /**
     * 角色权限变更后，刷新所有持有该角色的在线用户权限
     *
     * @param roleId            变更的角色ID
     * @param permissionService 权限服务
     */
    public void refreshPermissionByRoleId(Long roleId, SysPermissionService permissionService)
    {
        // 扫描所有在线 token
        String pattern = CacheConstants.LOGIN_TOKEN_KEY + "*";
        Collection<String> keys = scanKeys(pattern);
        if (keys == null || keys.isEmpty())
        {
            return;
        }
        for (String key : keys)
        {
            LoginUser loginUser = redisCache.getCacheObject(key);
            if (loginUser == null || loginUser.getUser() == null || loginUser.getUser().isAdmin())
            {
                // 管理员拥有所有权限，跳过
                continue;
            }
            // 判断该用户是否拥有此角色
            boolean hasRole = loginUser.getUser().getRoles() != null
                    && loginUser.getUser().getRoles().stream().anyMatch(r -> roleId.equals(r.getRoleId()));
            if (!hasRole)
            {
                continue;
            }
            // 刷新权限缓存
            loginUser.setPermissions(permissionService.getMenuPermission(loginUser.getUser()));
            refreshToken(loginUser);
            log.info("角色[{}]权限变更，已刷新在线用户[{}]的权限缓存", roleId, loginUser.getUsername());
        }
    }
}
