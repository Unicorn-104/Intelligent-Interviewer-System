package com.ruoyi.system.service.app.pdf;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import net.sourceforge.tess4j.Tesseract;
import com.ruoyi.system.config.ResumePdfProperties;

/** 从正式 JAR 的 Boot 类加载器执行合成扫描件，弥补仅测试 Maven 类路径的覆盖缺口。 */
public class ResumePdfPackagedSmoke
{
    public static void main(String[] args) throws Exception
    {
        if (args.length != 1) throw new IllegalArgumentException("Provide the synthetic scan PDF path");
        String version = Tesseract.class.getPackage().getImplementationVersion();
        System.out.println("Packaged Tess4J version: " + version);
        byte[] pdf = Files.readAllBytes(Path.of(args[0]));
        LocalResumePdfParser parser = new LocalResumePdfParser(new ResumePdfProperties());
        ExecutorService executor = Executors.newFixedThreadPool(2, task -> {
            Thread thread = new Thread(task, "packaged-ocr-smoke");
            thread.setDaemon(true);
            return thread;
        });
        try
        {
            List<Future<ResumePdfParser.Result>> futures = new ArrayList<>();
            for (int index = 0; index < 2; index++) futures.add(executor.submit(() -> parser.parse(pdf)));
            for (Future<ResumePdfParser.Result> future : futures)
            {
                ResumePdfParser.Result result = future.get();
                if (!"OCR".equals(result.method()) || !result.text().toLowerCase().contains("java"))
                    throw new IllegalStateException("Synthetic scan did not produce the expected OCR result");
                System.out.println("Packaged OCR succeeded; recognized characters: " + result.text().length());
            }
        }
        finally
        {
            executor.shutdownNow();
            parser.close();
        }
    }
}
