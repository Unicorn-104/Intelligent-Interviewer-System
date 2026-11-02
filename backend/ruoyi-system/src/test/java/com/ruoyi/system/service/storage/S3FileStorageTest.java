package com.ruoyi.system.service.storage;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.support.StaticListableBeanFactory;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import com.ruoyi.common.exception.ServiceException;
import com.ruoyi.system.config.FileStorageProperties;
import com.ruoyi.system.config.ResumePdfProperties;
import com.ruoyi.system.config.S3StorageConfiguration;
import com.ruoyi.system.service.app.pdf.ResumePdfStorage;
import com.ruoyi.system.service.app.pdf.ResumeAttachmentStorage;
import org.springframework.mock.web.MockMultipartFile;
import software.amazon.awssdk.services.s3.S3Client;
import static org.junit.jupiter.api.Assertions.*;

/** 本地 S3 HTTP 协议夹具，不代表已验证真实 RustFS 部署。 */
class S3FileStorageTest
{
    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties
    static class PropertyBinding { }

    private static final String KEY = "private-resume/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf";
    private final Map<String, byte[]> objects = new ConcurrentHashMap<>();
    private final AtomicInteger requests = new AtomicInteger();
    private HttpServer server;
    private S3Client client;
    private FileStorageProperties properties;
    private S3FileStorage storage;
    private volatile boolean signed;
    private volatile boolean deny;

    @BeforeEach void setup() throws Exception
    {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", this::handle);
        server.start();
        properties = new FileStorageProperties();
        properties.setProvider(FileStorageProperties.Provider.S3);
        properties.getS3().setEndpoint("http://127.0.0.1:" + server.getAddress().getPort());
        properties.getS3().setAccessKey("synthetic-access");
        properties.getS3().setSecretKey("synthetic-secret");
        client = new S3StorageConfiguration().fileStorageS3Client(properties);
        storage = new S3FileStorage(properties,
                new StaticListableBeanFactory(Map.of("s3", client)).getBeanProvider(S3Client.class));
    }

    @AfterEach void close()
    {
        if (client != null) client.close();
        if (server != null) server.stop(0);
    }

    @Test void usesSignedPathStyleRequestsAndRoundTripsOriginalBytes() throws Exception
    {
        byte[] bytes = "%PDF-synthetic".getBytes(StandardCharsets.UTF_8);
        String reference = storage.store(KEY, bytes, "application/pdf");
        assertEquals("s3:recruit-files/" + KEY, reference);
        assertArrayEquals(bytes, objects.get("/recruit-files/" + KEY));
        assertArrayEquals(bytes, storage.read(reference, 1024).getContentAsByteArray());
        assertTrue(signed);
        properties.getS3().setBucket("new-bucket");
        assertArrayEquals(bytes, storage.read(reference, 1024).getContentAsByteArray());
        storage.delete(reference);
        assertTrue(objects.isEmpty());
    }

    @Test void rejectsCrossUserAndPublicNamespaceBeforeReadingS3() throws Exception
    {
        ResumePdfStorage pdf = new ResumePdfStorage(new ResumePdfProperties(), storage);
        ResumePdfStorage.StoredPdf stored = pdf.store(17L, "%PDF-synthetic".getBytes(StandardCharsets.UTF_8), "resume.pdf");
        int before = requests.get();
        assertThrows(ServiceException.class, () -> pdf.readResource(18L, stored.reference()));
        String avatar = "s3:recruit-files/avatars/17/2026/11/02/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.png";
        assertThrows(ServiceException.class, () -> pdf.readResource(17L, avatar));
        assertThrows(ServiceException.class, () -> storage.read("s3:recruit-files/../outside.pdf", 1024));
        pdf.delete(18L, stored.reference());
        assertEquals(before, requests.get());
        assertArrayEquals("%PDF-synthetic".getBytes(StandardCharsets.UTF_8),
                pdf.readResource(17L, stored.reference()).getContentAsByteArray());
    }

    @Test void limitsObjectReadsAndHidesUpstreamFailureDetails()
    {
        String reference = storage.store(KEY, new byte[128], "application/pdf");
        assertThrows(ServiceException.class, () -> storage.read(reference, 8));
        deny = true;
        ServiceException error = assertThrows(ServiceException.class, () -> storage.read(reference, 1024));
        assertFalse(error.getMessage().contains("internal-detail"));
        assertFalse(error.getMessage().contains(properties.getS3().getEndpoint()));
    }

    @Test void localModeStartsWithoutCredentialsAndS3ModeBindsEnvironmentConfiguration()
    {
        new ApplicationContextRunner().withUserConfiguration(PropertyBinding.class, FileStorageProperties.class,
                S3StorageConfiguration.class, S3FileStorage.class)
                .run(context -> {
                    assertNull(context.getStartupFailure());
                    assertFalse(context.getBean(S3FileStorage.class).enabled());
                    assertTrue(context.getBeansOfType(S3Client.class).isEmpty());
                });
        new ApplicationContextRunner().withUserConfiguration(PropertyBinding.class, FileStorageProperties.class,
                S3StorageConfiguration.class, S3FileStorage.class)
                .withPropertyValues("app.storage.provider=s3", "app.storage.s3.endpoint=" + properties.getS3().getEndpoint(),
                        "app.storage.s3.access-key=synthetic-access", "app.storage.s3.secret-key=synthetic-secret")
                .run(context -> {
                    assertNull(context.getStartupFailure());
                    assertTrue(context.getBean(S3FileStorage.class).enabled());
                    assertEquals(1, context.getBeansOfType(S3Client.class).size());
                });
    }

    @Test void refusesMissingCredentialsAndNonRootEndpointsWithoutExposingValues()
    {
        properties.getS3().setSecretKey("");
        assertThrows(IllegalArgumentException.class, () -> new S3StorageConfiguration().fileStorageS3Client(properties));
        properties.getS3().setSecretKey("synthetic-secret");
        properties.getS3().setEndpoint("http://rustfs:9000/recruit-files");
        assertThrows(IllegalArgumentException.class, () -> new S3StorageConfiguration().fileStorageS3Client(properties));
    }

    @Test void privateAttachmentsUseObjectStorageAndEnforceOwnership() throws Exception
    {
        ResumeAttachmentStorage attachments = new ResumeAttachmentStorage(new ResumePdfProperties(), storage);
        byte[] bytes = "%PDF-synthetic".getBytes(StandardCharsets.UTF_8);
        ResumeAttachmentStorage.StoredAttachment saved = attachments.store(17L,
                new MockMultipartFile("files", "resume.pdf", "application/pdf", bytes));
        assertTrue(saved.reference().startsWith("s3:recruit-files/private-resume-attachment/17/"));
        assertArrayEquals(bytes, attachments.readResource(17L, saved.reference()).getContentAsByteArray());
        int before = requests.get();
        assertThrows(ServiceException.class, () -> attachments.readResource(18L, saved.reference()));
        attachments.delete(18L, saved.reference());
        assertEquals(before, requests.get());
        attachments.delete(17L, saved.reference());
        assertTrue(objects.isEmpty());
    }

    @Test void sharedUploadsUseObjectStorageAndKeepPublicPathsSeparateFromPrivateResumes() throws Exception
    {
        PublicUploadStorage uploads = new PublicUploadStorage(storage);
        byte[] bytes = "%PDF-synthetic".getBytes(StandardCharsets.UTF_8);
        PublicUploadStorage.Uploaded saved = uploads.store(17L,
                new MockMultipartFile("file", "attachment.pdf", "application/pdf", bytes));
        assertTrue(saved.path().startsWith("/profile/storage/uploads/17/"));
        assertArrayEquals(bytes, uploads.read(saved.path()).getContentAsByteArray());
        int before = requests.get();
        assertThrows(ServiceException.class, () -> uploads.read("/profile/storage/private-resume/17/file.pdf"));
        uploads.deleteNewObject(18L, saved.path());
        assertEquals(before, requests.get());
        uploads.deleteNewObject(17L, saved.path());
        assertTrue(objects.isEmpty());
    }

    private void handle(HttpExchange exchange) throws IOException
    {
        requests.incrementAndGet();
        String auth = exchange.getRequestHeaders().getFirst("Authorization");
        signed = auth != null && auth.startsWith("AWS4-HMAC-SHA256 ");
        String path = exchange.getRequestURI().getPath();
        byte[] body = exchange.getRequestBody().readAllBytes();
        byte[] response = new byte[0];
        int status = 200;
        if (deny)
        {
            status = 403;
            response = "<Error><Code>AccessDenied</Code><Message>internal-detail</Message></Error>".getBytes(StandardCharsets.UTF_8);
        }
        else switch (exchange.getRequestMethod())
        {
            case "PUT" -> objects.put(path, body);
            case "GET" -> {
                response = objects.get(path);
                if (response == null) { status = 404; response = new byte[0]; }
                exchange.getResponseHeaders().set("Content-Type", "application/pdf");
            }
            case "DELETE" -> { objects.remove(path); status = 204; }
            default -> status = 405;
        }
        exchange.sendResponseHeaders(status, response.length == 0 ? -1 : response.length);
        if (response.length > 0) exchange.getResponseBody().write(response);
        exchange.close();
    }
}
