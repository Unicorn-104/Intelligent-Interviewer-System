package com.ruoyi.framework.filter;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotSame;
import static org.junit.jupiter.api.Assertions.assertSame;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 接口版本前缀过滤器回归测试：/api/v1 重写、/api/v10 不误判
 */
public class ApiVersionPrefixFilterTest
{
    private final ApiVersionPrefixFilter filter = new ApiVersionPrefixFilter();

    @Test
    public void rewritesApiV1PrefixedPath() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/api/v1/system/user");
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(request, new MockHttpServletResponse(), chain);

        HttpServletRequest downstream = (HttpServletRequest) chain.getRequest();
        assertNotSame(request, downstream, "/api/v1 前缀路径应被包装重写");
        assertEquals("/system/user", downstream.getServletPath());
        assertEquals("/system/user", downstream.getRequestURI());
    }

    @Test
    public void doesNotRewriteApiV10Path() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/api/v10/system/user");
        request.setServletPath("/api/v10/system/user");
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(request, new MockHttpServletResponse(), chain);

        HttpServletRequest downstream = (HttpServletRequest) chain.getRequest();
        assertSame(request, downstream, "/api/v10 不应被误判为 /api/v1");
        assertEquals("/api/v10/system/user", downstream.getRequestURI());
        assertEquals("/api/v10/system/user", downstream.getServletPath());
    }

    @Test
    public void rewritesExactApiV1ToRoot() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/api/v1");
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(request, new MockHttpServletResponse(), chain);

        HttpServletRequest downstream = (HttpServletRequest) chain.getRequest();
        assertNotSame(request, downstream, "精确 /api/v1 应被重写为根路径");
        assertEquals("/", downstream.getServletPath());
        assertEquals("/", downstream.getRequestURI());
    }

    @Test
    public void leavesLegacyPathUntouched() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/system/user");
        request.setServletPath("/system/user");
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(request, new MockHttpServletResponse(), chain);

        assertSame(request, chain.getRequest(), "无版本前缀的旧路径不应被包装");
        assertEquals("/system/user", ((HttpServletRequest) chain.getRequest()).getServletPath());
    }

    @Test
    public void requestUrlReflectsRewrittenUriWithNonDefaultPort() throws Exception
    {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/api/v1/system/user");
        request.setScheme("http");
        request.setServerName("localhost");
        request.setServerPort(8080);
        MockFilterChain chain = new MockFilterChain();
        filter.doFilter(request, new MockHttpServletResponse(), chain);

        HttpServletRequest downstream = (HttpServletRequest) chain.getRequest();
        assertEquals("http://localhost:8080/system/user", downstream.getRequestURL().toString(),
                "getRequestURL 应使用重写后的 URI 且保留非默认端口");
    }

    @Test
    public void requestUrlOmitsDefaultPort() throws Exception
    {
        MockHttpServletRequest http = new MockHttpServletRequest();
        http.setRequestURI("/api/v1/system/user");
        http.setScheme("http");
        http.setServerName("example.com");
        http.setServerPort(80);
        MockFilterChain httpChain = new MockFilterChain();
        filter.doFilter(http, new MockHttpServletResponse(), httpChain);
        assertEquals("http://example.com/system/user",
                ((HttpServletRequest) httpChain.getRequest()).getRequestURL().toString(),
                "http 默认端口 80 不应出现在 URL 中");

        MockHttpServletRequest https = new MockHttpServletRequest();
        https.setRequestURI("/api/v1/system/user");
        https.setScheme("https");
        https.setServerName("example.com");
        https.setServerPort(443);
        MockFilterChain httpsChain = new MockFilterChain();
        filter.doFilter(https, new MockHttpServletResponse(), httpsChain);
        assertEquals("https://example.com/system/user",
                ((HttpServletRequest) httpsChain.getRequest()).getRequestURL().toString(),
                "https 默认端口 443 不应出现在 URL 中");
    }
}
