param([int]$ExpectedBackendPid = 0, [switch]$SkipMigration)
$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $backendRoot

try {
    # Credential stays in this process and its backend child; never in files or arguments.
    $secureDbPassword = Read-Host 'Local MySQL password (hidden)' -AsSecureString
    $localCredential = [PSCredential]::new('root', $secureDbPassword)
    $env:DB_PASSWORD = $localCredential.GetNetworkCredential().Password
    if ($SkipMigration) { python .\tools\migrate_ai_local.py --verify-only }
    else { python .\tools\migrate_ai_local.py }
    if ($LASTEXITCODE -ne 0) { throw 'Database verification failed; existing backend was not stopped.' }

    $listeners = @(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique)
    if ($listeners.Count -gt 0) {
        if ($listeners.Count -ne 1 -or $ExpectedBackendPid -eq 0 -or $listeners[0] -ne $ExpectedBackendPid) {
            throw 'Port 8080 ownership changed. Existing service was not stopped.'
        }
        $existingBackend = Get-CimInstance Win32_Process -Filter "ProcessId = $ExpectedBackendPid"
        if ($existingBackend.CommandLine -notmatch 'ruoyi-admin[/\\]target[/\\]ruoyi-admin.jar') {
            throw 'Unexpected process on port 8080. Existing service was not stopped.'
        }
        Stop-Process -Id $ExpectedBackendPid -Force
        Wait-Process -Id $ExpectedBackendPid -ErrorAction SilentlyContinue
    }

    mvn -DskipTests package
    if ($LASTEXITCODE -ne 0) { throw 'Backend build failed. Fix the build before restarting.' }
    $dbUrl = 'jdbc:mysql://localhost:3306/recruit_agent?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=GMT%2B8'
    $logStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backendJava = (Get-Command java).Source
    $started = Start-Process -FilePath $backendJava -ArgumentList @('-jar', 'ruoyi-admin/target/ruoyi-admin.jar', "--spring.datasource.druid.master.url=$dbUrl", '--spring.main.lazy-initialization=true') -WorkingDirectory $backendRoot -WindowStyle Hidden -RedirectStandardOutput "run/backend-ai-$logStamp.out.log" -RedirectStandardError "run/backend-ai-$logStamp.err.log" -PassThru
    Write-Host "Backend starting. PID: $($started.Id). Return to the app and reload after startup."
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    Remove-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue
}
Read-Host 'Press Enter to close this setup window'
