package com.ruoyi.web.controller.common;

import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.common.core.domain.entity.SysUser;
import com.ruoyi.common.core.domain.model.LoginUser;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.framework.config.ServerConfig;
import com.ruoyi.system.service.storage.PublicUploadStorage;
import com.ruoyi.web.controller.system.ImController;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class CommonFileStorageTest
{
    private static final String PATH = "/profile/storage/uploads/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf";
    private final PublicUploadStorage storage = mock(PublicUploadStorage.class);
    private MockMvc mvc;

    @BeforeEach void setup()
    {
        ServerConfig server = mock(ServerConfig.class);
        when(server.getUrl()).thenReturn("https://backend.example.com");
        CommonController common = new CommonController();
        ReflectionTestUtils.setField(common, "serverConfig", server);
        ReflectionTestUtils.setField(common, "uploadStorage", storage);
        ImController im = new ImController();
        ReflectionTestUtils.setField(im, "serverConfig", server);
        ReflectionTestUtils.setField(im, "uploadStorage", storage);
        mvc = MockMvcBuilders.standaloneSetup(common, im).build();
        LoginUser user = new LoginUser(17L, 1L, new SysUser(), Set.of());
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(user, null, Set.of()));
    }

    @AfterEach void cleanup() { SecurityContextHolder.clearContext(); }

    private MockMultipartFile file(String field)
    {
        return new MockMultipartFile(field, "attachment.pdf", "application/pdf", "%PDF-synthetic".getBytes());
    }

    @Test void commonAndImUploadsReturnTheSameCrossClientResourceContract() throws Exception
    {
        when(storage.store(eq(17L), any())).thenReturn(new PublicUploadStorage.Uploaded(PATH, "attachment.pdf", 14, "application/pdf"));
        for (String endpoint : new String[] {"/common/upload", "/system/im/attachments"})
        {
            mvc.perform(multipart(endpoint).file(file("file")))
                    .andExpect(status().isOk()).andExpect(jsonPath("$.code").value(200))
                    .andExpect(jsonPath("$.fileName").value(PATH))
                    .andExpect(jsonPath("$.url").value("https://backend.example.com" + PATH))
                    .andExpect(jsonPath("$.originalFilename").value("attachment.pdf"));
        }
        verify(storage, times(2)).store(eq(17L), any());
    }

    @Test void multiUploadFailureCleansOnlyObjectsCreatedByThisRequest() throws Exception
    {
        when(storage.store(eq(17L), any()))
                .thenReturn(new PublicUploadStorage.Uploaded(PATH, "attachment.pdf", 14, "application/pdf"))
                .thenThrow(new ServiceException("合成上传故障"));
        mvc.perform(multipart("/common/uploads").file(file("files")).file(file("files")))
                .andExpect(jsonPath("$.code").value(500));
        verify(storage).deleteNewObject(17L, PATH);
    }

    @Test void existingResourceDownloadEndpointAlsoReadsCloudBackedPublicUploads() throws Exception
    {
        byte[] bytes = "%PDF-synthetic".getBytes();
        when(storage.isStoredPath(PATH)).thenReturn(true);
        when(storage.read(PATH)).thenReturn(new ByteArrayResource(bytes));
        mvc.perform(get("/common/download/resource").param("resource", PATH))
                .andExpect(status().isOk()).andExpect(content().bytes(bytes));
        verify(storage).read(PATH);
    }
}
