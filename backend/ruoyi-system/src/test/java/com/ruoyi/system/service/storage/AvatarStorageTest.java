package com.ruoyi.system.service.storage;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.nio.file.Path;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import com.ruoyi.common.config.RuoYiConfig;
import com.ruoyi.common.exception.ServiceException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AvatarStorageTest
{
    @TempDir Path directory;
    private final S3FileStorage objects = mock(S3FileStorage.class);
    private final AvatarStorage storage = new AvatarStorage(objects);

    private byte[] png() throws Exception
    {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB), "png", out);
        return out.toByteArray();
    }

    @Test void returnsBackendAvatarUrlWithoutInternalEndpointOrCredentials() throws Exception
    {
        when(objects.enabled()).thenReturn(true);
        when(objects.store(anyString(), any(), eq("image/png")))
                .thenAnswer(invocation -> "s3:recruit-files/" + invocation.getArgument(0, String.class));
        when(objects.reference(anyString())).thenAnswer(invocation -> "s3:recruit-files/" + invocation.getArgument(0, String.class));
        String url = storage.store(17L, new MockMultipartFile("avatarfile", "image.png", "image/png", png()));
        assertTrue(url.matches("/profile/storage/avatars/17/[0-9/]+/[a-f0-9]{32}\\.png"));
        storage.delete(17L, url);
        verify(objects).delete("s3:recruit-files/" + url.substring(AvatarStorage.URL_PREFIX.length()));
    }

    @Test void preservesLocalAvatarBehaviorWhenS3IsDisabled() throws Exception
    {
        new RuoYiConfig().setProfile(directory.resolve("public-upload").toString());
        String url = storage.store(17L, new MockMultipartFile("avatarfile", "image.png", "image/png", png()));
        Path file = directory.resolve("public-upload").resolve(url.substring("/profile/".length()));
        assertTrue(java.nio.file.Files.exists(file));
        storage.delete(17L, url);
        assertFalse(java.nio.file.Files.exists(file));
        verify(objects, never()).store(any(), any(), any());
    }

    @Test void rejectsDisguisedImageAndConflictingMimeBeforeUploading() throws Exception
    {
        assertThrows(ServiceException.class, () -> storage.store(17L,
                new MockMultipartFile("avatarfile", "image.jpg", "image/jpeg", png())));
        assertThrows(ServiceException.class, () -> storage.store(17L,
                new MockMultipartFile("avatarfile", "image.png", "image/png", "<script>bad</script>".getBytes())));
        assertThrows(ServiceException.class, () -> storage.store(17L,
                new MockMultipartFile("avatarfile", "image.png", "text/html", png())));
        verifyNoInteractions(objects);
    }

    @Test void publicReaderAndCleanupCannotReachPrivateOrAnotherUsersFiles()
    {
        String file = "2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png";
        assertThrows(ServiceException.class, () -> storage.read("private-resume/17/" + file));
        storage.delete(17L, "/profile/storage/avatars/18/" + file);
        storage.delete(17L, "/profile/storage/private-resume/17/" + file.replace("png", "pdf"));
        storage.delete(17L, "/profile/avatar/../../private/file.png");
        verifyNoInteractions(objects);
    }

    @Test void longestUserIdStillFitsLegacyAvatarColumn() throws Exception
    {
        when(objects.enabled()).thenReturn(true);
        String url = storage.store(Long.MAX_VALUE,
                new MockMultipartFile("avatarfile", "image.png", "image/png", png()));
        assertTrue(url.length() <= 100);
    }
}
