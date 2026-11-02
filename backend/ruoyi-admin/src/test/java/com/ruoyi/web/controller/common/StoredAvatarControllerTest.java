package com.ruoyi.web.controller.common;

import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import com.ruoyi.system.service.storage.AvatarStorage;
import com.ruoyi.system.service.storage.S3FileStorage;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class StoredAvatarControllerTest
{
    private final S3FileStorage objects = mock(S3FileStorage.class);
    private final MockMvc mvc = MockMvcBuilders.standaloneSetup(
            new StoredAvatarController(new AvatarStorage(objects))).build();

    @Test void servesOnlyAvatarNamespaceWithImageContentType() throws Exception
    {
        byte[] bytes = "synthetic-image".getBytes(StandardCharsets.UTF_8);
        when(objects.read(anyString(), anyInt())).thenReturn(new ByteArrayResource(bytes));
        when(objects.reference(anyString())).thenAnswer(invocation -> "s3:recruit-files/" + invocation.getArgument(0, String.class));
        String path = "/profile/storage/avatars/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png";
        mvc.perform(get(path)).andExpect(status().isOk())
                .andExpect(content().contentType("image/png")).andExpect(content().bytes(bytes))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"));
        verify(objects).read("s3:recruit-files/avatars/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png", 5 * 1024 * 1024);
    }

    @Test void privateNamespaceAndInvalidFilenameAreNeverReadFromS3() throws Exception
    {
        mvc.perform(get("/profile/storage/private-resume/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf"))
                .andExpect(status().isNotFound());
        mvc.perform(get("/profile/storage/avatars/17/2026/11/02/invalid.pdf"))
                .andExpect(status().isNotFound());
        verifyNoInteractions(objects);
    }
}
