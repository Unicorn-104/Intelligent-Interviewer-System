package com.ruoyi.web.controller.system;

import java.util.Set;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.framework.web.service.TokenService;
import com.ruoyi.system.service.ISysUserService;
import com.ruoyi.system.service.storage.AvatarStorage;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class SysProfileStorageTest
{
    private static final String OLD = "/profile/avatar/2026/11/02/old.png";
    private static final String NEW = "/profile/storage/avatars/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png";
    private final ISysUserService users = mock(ISysUserService.class);
    private final AvatarStorage files = mock(AvatarStorage.class);
    private final TokenService tokens = mock(TokenService.class);
    private MockMvc mvc;
    private LoginUser login;

    @BeforeEach void setup() throws Exception
    {
        SysProfileController controller = new SysProfileController();
        ReflectionTestUtils.setField(controller, "userService", users);
        ReflectionTestUtils.setField(controller, "avatarStorage", files);
        ReflectionTestUtils.setField(controller, "tokenService", tokens);
        mvc = MockMvcBuilders.standaloneSetup(controller).build();
        SysUser user = new SysUser();
        user.setAvatar(OLD);
        login = new LoginUser(17L, 1L, user, Set.of());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(login, null, Set.of()));
        when(files.store(eq(17L), any())).thenReturn(NEW);
    }

    @AfterEach void cleanup() { SecurityContextHolder.clearContext(); }

    private MockMultipartFile image()
    {
        return new MockMultipartFile("avatarfile", "image.png", "image/png", new byte[] {1});
    }

    @Test void keepsResponseFieldAndDeletesOldAvatarOnlyAfterSuccessfulUpdate() throws Exception
    {
        when(users.updateUserAvatar(17L, NEW)).thenReturn(true);
        mvc.perform(multipart("/system/user/profile/avatar").file(image()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.imgUrl").value(NEW));
        assertEquals(NEW, login.getUser().getAvatar());
        var ordered = inOrder(users, tokens, files);
        ordered.verify(files).store(eq(17L), any());
        ordered.verify(users).updateUserAvatar(17L, NEW);
        ordered.verify(tokens).setLoginUser(login);
        ordered.verify(files).delete(17L, OLD);
    }

    @Test void explicitDatabaseRefusalCleansNewFileAndKeepsOldAvatar() throws Exception
    {
        when(users.updateUserAvatar(17L, NEW)).thenReturn(false);
        mvc.perform(multipart("/system/user/profile/avatar").file(image()))
                .andExpect(jsonPath("$.code").value(500));
        verify(files).delete(17L, NEW);
        verify(files, never()).delete(17L, OLD);
        verifyNoInteractions(tokens);
        assertEquals(OLD, login.getUser().getAvatar());
    }

    @Test void unknownDatabaseOutcomeDoesNotDeletePotentiallyCommittedFile() throws Exception
    {
        when(users.updateUserAvatar(17L, NEW)).thenThrow(new IllegalStateException("synthetic timeout"));
        assertThrows(ServletException.class, () -> mvc.perform(multipart("/system/user/profile/avatar").file(image())));
        verify(files, never()).delete(any(), any());
    }
}
