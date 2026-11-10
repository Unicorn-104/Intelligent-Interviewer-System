package com.ruoyi.web.controller.app;

import java.io.IOException;
import java.util.List;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mock.web.MockServletContext;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.support.AnnotationConfigWebApplicationContext;
import org.springframework.web.filter.CorsFilter;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import com.ruoyi.framework.config.SecurityConfig;
import com.ruoyi.framework.config.properties.PermitAllUrlProperties;
import com.ruoyi.framework.security.filter.JwtAuthenticationTokenFilter;
import com.ruoyi.framework.security.handle.AuthenticationEntryPointImpl;
import com.ruoyi.framework.security.handle.LogoutSuccessHandlerImpl;
import com.ruoyi.framework.web.service.TokenService;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class GuestJobSecurityTest
{
    static class ExposedSecurityConfig extends SecurityConfig
    {
        SecurityFilterChain build(HttpSecurity http) throws Exception { return filterChain(http); }
    }

    @Configuration
    @EnableWebSecurity
    static class TestSecurity
    {
        @Bean
        SecurityFilterChain chain(HttpSecurity http) throws Exception
        {
            var config = new ExposedSecurityConfig();
            var urls = mock(PermitAllUrlProperties.class);
            when(urls.getUrls()).thenReturn(List.of());
            ReflectionTestUtils.setField(config, "permitAllUrl", urls);
            ReflectionTestUtils.setField(config, "unauthorizedHandler", new AuthenticationEntryPointImpl());
            ReflectionTestUtils.setField(config, "logoutSuccessHandler", mock(LogoutSuccessHandlerImpl.class));
            ReflectionTestUtils.setField(config, "corsFilter", new CorsFilter(new UrlBasedCorsConfigurationSource()));
            var jwt = new JwtAuthenticationTokenFilter();
            ReflectionTestUtils.setField(jwt, "tokenService", mock(TokenService.class));
            ReflectionTestUtils.setField(config, "authenticationTokenFilter", jwt);
            return config.build(http);
        }
    }

    @Test
    void onlyExplicitPublicGetRoutesBypassAuthentication() throws Exception
    {
        try (var context = new AnnotationConfigWebApplicationContext())
        {
            context.setServletContext(new MockServletContext());
            context.register(TestSecurity.class);
            context.refresh();
            var mvc = MockMvcBuilders.webAppContextSetup(context)
                    .addFilters(context.getBean("springSecurityFilterChain", Filter.class)).build();
            // No controller is registered: 404 proves the request reached dispatch after authorization.
            for (String path : List.of("/app/jobs", "/app/jobs/search", "/app/jobs/filter-options", "/app/jobs/public/7"))
                mvc.perform(get(path)).andExpect(status().isNotFound());
            for (String path : List.of("/app/jobs/favorites", "/app/jobs/7/favorite", "/app/ai/knowledge/documents",
                    "/app/resumes", "/system/conference/schedule", "/app/jobs/public/7/extra"))
                mvc.perform(get(path)).andExpect(jsonPath("$.code").value(401));
            mvc.perform(post("/app/jobs/7/apply")).andExpect(jsonPath("$.code").value(401));
        }
    }
}
