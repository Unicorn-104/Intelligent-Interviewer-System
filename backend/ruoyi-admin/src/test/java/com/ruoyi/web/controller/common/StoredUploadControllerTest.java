package com.ruoyi.web.controller.common;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.system.service.storage.PublicUploadStorage;
import com.ruoyi.system.service.storage.S3FileStorage;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class StoredUploadControllerTest
{
    private final S3FileStorage objects = mock(S3FileStorage.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(
            new StoredUploadController(new PublicUploadStorage(objects))).build();

    @Test void publicImagesAndDocumentsKeepTheirContentTypesAndNeverExposeStorageAddress() throws Exception
    {
        when(objects.reference(anyString())).thenAnswer(call -> "s3:recruit-files/" + call.getArgument(0, String.class));
        when(objects.read(anyString(), anyInt())).thenReturn(new ByteArrayResource(new byte[] {1, 2, 3}));
        String path = "/profile/storage/uploads/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.";
        mvc.perform(get(path + "png")).andExpect(status().isOk()).andExpect(content().contentType("image/png"))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"));
        mvc.perform(get(path + "pdf")).andExpect(status().isOk()).andExpect(content().contentType("application/pdf"))
                .andExpect(header().doesNotExist("Location"));
    }

    @Test void publicProxyCannotReadPrivateResumeNamespaceOrAcceptArbitraryFileKeys() throws Exception
    {
        mvc.perform(get("/profile/storage/private-resume/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf"))
                .andExpect(status().isNotFound());
        when(objects.reference(anyString())).thenAnswer(call -> "s3:recruit-files/" + call.getArgument(0, String.class));
        // 无效文件名在引用校验阶段被拒绝，不会向 S3 发出读取请求。
        mvc.perform(get("/profile/storage/uploads/17/2026/11/02/not-generated.pdf"))
                .andExpect(status().isNotFound());
        verify(objects, never()).read(anyString(), anyInt());
    }
}
