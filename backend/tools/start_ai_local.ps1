param(
    [int]$ExpectedBackendPid = 0,
    [switch]$SkipMigration,
    [ValidateSet('s3', 'local')][string]$FileStorageProvider = 's3'
)
$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $backendRoot
$storageVariables = @('FILE_STORAGE_PROVIDER', 'FILE_STORAGE_S3_ENDPOINT', 'FILE_STORAGE_S3_BUCKET', 'FILE_STORAGE_S3_REGION', 'FILE_STORAGE_S3_ACCESS_KEY', 'FILE_STORAGE_S3_SECRET_KEY')
$previousStorageEnvironment = @{}
foreach ($name in $storageVariables) {
    $previousStorageEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    # New uploads default to RustFS. Explicit local mode remains available for legacy development.
    $env:FILE_STORAGE_PROVIDER = $FileStorageProvider
    if ($FileStorageProvider -eq 's3') {
        if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_ENDPOINT)) { $env:FILE_STORAGE_S3_ENDPOINT = 'http://127.0.0.1:9000' }
        if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_BUCKET)) { $env:FILE_STORAGE_S3_BUCKET = 'recruit-files' }
        if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_REGION)) { $env:FILE_STORAGE_S3_REGION = 'us-east-1' }
        $storageUri = $null
        if (-not [Uri]::TryCreate($env:FILE_STORAGE_S3_ENDPOINT, [UriKind]::Absolute, [ref]$storageUri) -or
            $storageUri.Scheme -notin @('http', 'https') -or $storageUri.UserInfo -or $storageUri.Query -or $storageUri.Fragment -or
            $storageUri.AbsolutePath -notin @('', '/')) {
            throw 'Invalid RustFS API endpoint; credentials must use environment variables, not URLs.'
        }
        if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_ACCESS_KEY) -or [string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_SECRET_KEY)) {
            if (-not [string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_ACCESS_KEY) -or -not [string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_SECRET_KEY)) {
                throw 'Provide both RustFS credential variables together; existing backend was not stopped.'
            }
            # Only use local-container credentials for its published loopback API, never a remote endpoint.
            if ($storageUri.Host -notin @('127.0.0.1', 'localhost', '::1')) {
                throw 'Remote storage requires FILE_STORAGE_S3_ACCESS_KEY and FILE_STORAGE_S3_SECRET_KEY.'
            }
            $containerJson = & docker inspect rustfs 2>$null
            if ($LASTEXITCODE -ne 0) { throw 'Local RustFS container is unavailable; existing backend was not stopped.' }
            $container = @($containerJson | ConvertFrom-Json)[0]
            if (-not $container.State.Running) { throw 'Start the local RustFS container before starting the backend.' }
            $publishedPorts = @($container.NetworkSettings.Ports.'9000/tcp' | Where-Object {
                $_.HostIp -in @('127.0.0.1', '::1', '0.0.0.0', '::')
            } | ForEach-Object { [int]$_.HostPort })
            if ($storageUri.Port -notin $publishedPorts) { throw 'RustFS API endpoint does not match the local container published port.' }
            $containerCredentials = @{}
            foreach ($setting in $container.Config.Env) {
                $pair = $setting -split '=', 2
                if ($pair.Count -eq 2 -and $pair[0] -in @('RUSTFS_ACCESS_KEY', 'RUSTFS_SECRET_KEY')) { $containerCredentials[$pair[0]] = $pair[1] }
            }
            if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_ACCESS_KEY)) { $env:FILE_STORAGE_S3_ACCESS_KEY = $containerCredentials['RUSTFS_ACCESS_KEY'] }
            if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_SECRET_KEY)) { $env:FILE_STORAGE_S3_SECRET_KEY = $containerCredentials['RUSTFS_SECRET_KEY'] }
        }
        if ([string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_ACCESS_KEY) -or [string]::IsNullOrWhiteSpace($env:FILE_STORAGE_S3_SECRET_KEY)) {
            throw 'RustFS credentials are missing; existing backend was not stopped.'
        }
        Write-Host "File storage: RustFS/S3, endpoint $($env:FILE_STORAGE_S3_ENDPOINT), bucket $($env:FILE_STORAGE_S3_BUCKET)."
    }
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
    New-Item -ItemType Directory -Path (Join-Path $backendRoot 'run') -Force | Out-Null
    $started = Start-Process -FilePath $backendJava -ArgumentList @('-jar', 'ruoyi-admin/target/ruoyi-admin.jar', "--spring.datasource.druid.master.url=$dbUrl", '--spring.main.lazy-initialization=true', "--app.storage.provider=$FileStorageProvider") -WorkingDirectory $backendRoot -WindowStyle Hidden -RedirectStandardOutput "run/backend-ai-$logStamp.out.log" -RedirectStandardError "run/backend-ai-$logStamp.err.log" -PassThru
    Write-Host "Backend starting. PID: $($started.Id). Return to the app and reload after startup."
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    Remove-Item Env:DB_PASSWORD -ErrorAction SilentlyContinue
    foreach ($name in $storageVariables) {
        [Environment]::SetEnvironmentVariable($name, $previousStorageEnvironment[$name], 'Process')
    }
    $containerCredentials = $container = $containerJson = $pair = $setting = $null
    $previousStorageEnvironment = $null
}
Read-Host 'Press Enter to close this setup window'
