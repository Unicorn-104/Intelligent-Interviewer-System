# RustFS 对象复制脚本（RemoteException 修复版）：仅处理 appId 70/71/78
# 默认 Dry Run；必须显式 -Execute 才真正写入
# 统一封装 Invoke-Aws：调用原生 aws 期间临时放宽 ErrorActionPreference，
# 避免 PS5.1 把原生 stderr 提升为终止性 RemoteException；立即捕获退出码与完整输出
# 错误分类：仅明确 404 判不存在，403/412/409/5xx/网络分别处理
# 报告独占创建不覆盖；失败后未执行记录为 NOT_ATTEMPTED；不连接数据库
# 兼容 Windows PowerShell 5.1 与 pwsh 7

param(
    [switch]$Execute,
    [switch]$ConditionalWriteVerified,
    [string]$EndpointUrl = "http://127.0.0.1:19000",
    [string]$Bucket = "recruit-files",
    [string]$Region = "us-east-1",
    [string]$ReportPath = "copy_result_report.csv",
    [string]$EvidencePath = "conditional_write_evidence.json"
)

$ErrorActionPreference = 'Stop'

# 固定工作项：仅这三条，禁止加入其他 appId
$items = @(
    [pscustomobject]@{
        AppId = 70
        SourceKey = 'private-resume/104/2026/11/04/226ebc017a1b426b9ffc052a2be93542.pdf'
        TargetKey = 'enterprise-application-resume/1/70/f7265a2484e44f1bb8f28eb898e517d3.pdf'
        ExpectedSize = 309407
        ExpectedSha = 'd4da83f8d56c7b65e8a36cc5ed35d188cea66ec0c84e36243440e9b172230022'
    },
    [pscustomobject]@{
        AppId = 71
        SourceKey = 'private-resume/2/2026/11/03/1094f8750f774eb19983a4d14e205567.pdf'
        TargetKey = 'enterprise-application-resume/1/71/41b70c7ec33e42be9bfbe584645935a0.pdf'
        ExpectedSize = 163683
        ExpectedSha = 'e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda'
    },
    [pscustomobject]@{
        AppId = 78
        SourceKey = 'private-resume/2/2026/11/03/1094f8750f774eb19983a4d14e205567.pdf'
        TargetKey = 'enterprise-application-resume/1/78/18a5a19616884d64a492decd1f86a4e8.pdf'
        ExpectedSize = 163683
        ExpectedSha = 'e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda'
    }
)

# 报告独占创建
if (Test-Path -LiteralPath $ReportPath) {
    throw "报告文件已存在：$ReportPath，请指定新的 -ReportPath，不覆盖不删除。"
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "未找到 aws CLI"
}

# 统一 AWS CLI 调用封装：临时放宽原生 stderr 处理，捕获完整输出与退出码
function Invoke-Aws {
    param([string[]]$Arguments)
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $merged = & aws @Arguments 2>&1
        $code = $LASTEXITCODE
        $text = ($merged | Out-String)
        return [pscustomobject]@{
            ExitCode = $code
            Text = $text
        }
    }
    finally {
        $ErrorActionPreference = $prevEAP
    }
}

# 统一错误码分类：412/409/404/403/5xx/网络
function Get-AwsErrorKind {
    param([string]$Text)
    if ($Text -match 'PreconditionFailed' -or $Text -match '412') { return 'HTTP_412_PRECONDITION_FAILED' }
    if ($Text -match 'Conflict' -or $Text -match '409') { return 'HTTP_409_CONFLICT' }
    if ($Text -match 'NotFound' -or $Text -match 'NoSuchKey' -or $Text -match '404') { return 'HTTP_404_NOT_FOUND' }
    if ($Text -match 'AccessDenied' -or $Text -match 'Forbidden' -or $Text -match '403') { return 'HTTP_403_ACCESS_DENIED' }
    if ($Text -match '5[0-9][0-9]') { return 'HTTP_5XX_SERVER_ERROR' }
    return 'NETWORK_OR_UNKNOWN'
}

# 64 hex 校验
function Test-ShaHex {
    param([string]$Value)
    return ($Value -match '^[a-f0-9]{64}$')
}

# 证据全字段校验
function Assert-ConditionalWriteEvidence {
    if (-not (Test-Path -LiteralPath $EvidencePath)) {
        throw "EVIDENCE_MISSING：缺少证据文件 $EvidencePath，须先执行 test_conditional_write.ps1 真实探测"
    }
    $evi = [IO.File]::ReadAllText($EvidencePath) | ConvertFrom-Json

    if ($evi.endpoint -ne $EndpointUrl) { throw "EVIDENCE_ENDPOINT_MISMATCH" }
    if ($evi.bucket -ne $Bucket) { throw "EVIDENCE_BUCKET_MISMATCH" }
    if ($evi.region -ne $Region) { throw "EVIDENCE_REGION_MISMATCH" }
    if ($evi.versionVerification -ne 'MANUAL_VERIFICATION') {
        throw "EVIDENCE_VERSION_NOT_MANUAL：版本须人工核验"
    }
    if ($evi.rustfsVersion -eq 'NOT_VERIFIED' -or
        $evi.rustfsVersion -like 'FILL_*' -or
        [string]::IsNullOrWhiteSpace($evi.rustfsVersion)) {
        throw "EVIDENCE_RUSTFS_VERSION_INVALID：须为真实版本且与实例一致"
    }
    if ($evi.probeKey -notlike 'conditional-write-probe/*') {
        throw "EVIDENCE_PROBE_KEY_INVALID：探测 key 须在独立前缀"
    }
    if ($evi.firstPutStatus -ne 'HTTP_200_OK') { throw "EVIDENCE_FIRST_PUT_NOT_OK" }
    if ($evi.secondPutStatus -ne 'HTTP_412_PRECONDITION_FAILED') {
        throw "EVIDENCE_SECOND_PUT_NOT_412（409 不算成功）"
    }
    if (-not (Test-ShaHex $evi.firstObjectSha256) -or
        -not (Test-ShaHex $evi.finalObjectSha256)) {
        throw "EVIDENCE_SHA_INVALID"
    }
    if ($evi.firstObjectSha256 -ne $evi.finalObjectSha256) {
        throw "EVIDENCE_SHA_MISMATCH：无法证明第二次请求未覆盖"
    }
    if ($evi.verifiedAt -eq 'NOT_VERIFIED' -or $evi.verifiedBy -eq 'NOT_VERIFIED') {
        throw "EVIDENCE_TRACEABILITY_INCOMPLETE：verifiedAt/verifiedBy 缺失"
    }
    if ($evi.result -ne 'VERIFIED') { throw "EVIDENCE_RESULT_NOT_VERIFIED" }
    return $evi
}

if ($Execute) {
    if (-not $ConditionalWriteVerified) {
        throw "阻断：条件写能力尚未验证，证据未通过，禁止以 HEAD 冒充 CREATE_NEW"
    }
    $evidence = Assert-ConditionalWriteEvidence
    Write-Host "证据校验通过：endpoint=$EndpointUrl bucket=$Bucket RustFS=$($evidence.rustfsVersion)"
}

# HEAD 分类：仅明确 404 判不存在，其余错误码一律停止
function Get-HeadState {
    param([string]$Key)
    $r = Invoke-Aws -Arguments @(
        's3api','head-object','--endpoint-url',$EndpointUrl,'--region',$Region,
        '--bucket',$Bucket,'--key',$Key
    )
    if ($r.ExitCode -eq 0) { return 'EXISTS' }
    $kind = Get-AwsErrorKind -Text $r.Text
    if ($kind -eq 'HTTP_404_NOT_FOUND') { return 'NOT_FOUND' }
    throw "HEAD_FAILED:$kind；$($r.Text.Trim())"
}

# 凭据与环境变量初始化
$skInput = $null
$prevAk = $null
$prevSk = $null
$prevNoProxy = $null
$prevNoProxyLower = $null
$tempFiles = New-Object System.Collections.Generic.List[string]
$sourceCache = @{}
$results = New-Object System.Collections.Generic.List[object]
$stopLoop = $false

try {
    $prevAk = $env:AWS_ACCESS_KEY_ID
    $prevSk = $env:AWS_SECRET_ACCESS_KEY
    $prevNoProxy = $env:NO_PROXY
    $prevNoProxyLower = $env:no_proxy

    if ([string]::IsNullOrWhiteSpace($env:AWS_ACCESS_KEY_ID) -or
        [string]::IsNullOrWhiteSpace($env:AWS_SECRET_ACCESS_KEY)) {
        $akInput = Read-Host "RustFS Access Key"
        $skInput = Read-Host "RustFS Secret Key" -AsSecureString
        $env:AWS_ACCESS_KEY_ID = $akInput
        $env:AWS_SECRET_ACCESS_KEY = (New-Object System.Management.Automation.PSCredential(
            "ignore", $skInput)).GetNetworkCredential().Password
    }
    $env:NO_PROXY = "127.0.0.1,localhost"
    $env:no_proxy = "127.0.0.1,localhost"

    $mode = if ($Execute) { "EXECUTE" } else { "DRY_RUN" }
    Write-Host "模式=$mode endpoint=$EndpointUrl bucket=$Bucket"

    foreach ($it in $items) {
        # 前序失败：未执行记录登记为 NOT_ATTEMPTED
        if ($stopLoop) {
            $results.Add([pscustomobject]@{
                appId = $it.AppId; SourceKey = $it.SourceKey; TargetKey = $it.TargetKey
                ExpectedSize = $it.ExpectedSize; ActualSize = $null
                ExpectedSha = $it.ExpectedSha; ActualSha = $null
                CopyStatus = 'NOT_ATTEMPTED'; Error = '前序记录失败，本条未执行'
            })
            continue
        }
        Write-Host "--- appId=$($it.AppId) ---"

        $record = [pscustomobject]@{
            appId = $it.AppId; SourceKey = $it.SourceKey; TargetKey = $it.TargetKey
            ExpectedSize = $it.ExpectedSize; ActualSize = $null
            ExpectedSha = $it.ExpectedSha; ActualSha = $null
            CopyStatus = 'FAILED'; Error = ''
        }

        try {
            # 1) 源对象复核：同源只读一次
            if (-not $sourceCache.ContainsKey($it.SourceKey)) {
                $srcTmp = [IO.Path]::GetTempFileName()
                $tempFiles.Add($srcTmp)
                $r = Invoke-Aws -Arguments @(
                    's3api','get-object','--endpoint-url',$EndpointUrl,'--region',$Region,
                    '--bucket',$Bucket,'--key',$it.SourceKey,$srcTmp
                )
                if ($r.ExitCode -ne 0) {
                    throw "SOURCE_GET_FAILED:$(Get-AwsErrorKind -Text $r.Text)；$($r.Text.Trim())"
                }
                $srcSize = (Get-Item -LiteralPath $srcTmp).Length
                $srcSha = (Get-FileHash -LiteralPath $srcTmp -Algorithm SHA256).Hash.ToLower()
                if ($srcSize -ne $it.ExpectedSize -or $srcSha -ne $it.ExpectedSha) {
                    throw "SOURCE_VERIFY_FAILED：大小或 SHA 不匹配"
                }
                $sourceCache[$it.SourceKey] = [pscustomobject]@{
                    Tmp = $srcTmp; Size = $srcSize; Sha = $srcSha
                }
            }
            $cached = $sourceCache[$it.SourceKey]
            $record.ActualSize = $cached.Size
            $record.ActualSha = $cached.Sha

            # 2) 目标 HEAD 分类
            $headState = Get-HeadState -Key $it.TargetKey

            if ($headState -eq 'EXISTS') {
                $tgtTmp = [IO.Path]::GetTempFileName()
                $tempFiles.Add($tgtTmp)
                $r = Invoke-Aws -Arguments @(
                    's3api','get-object','--endpoint-url',$EndpointUrl,'--region',$Region,
                    '--bucket',$Bucket,'--key',$it.TargetKey,$tgtTmp
                )
                if ($r.ExitCode -ne 0) {
                    throw "TARGET_GET_FAILED:$(Get-AwsErrorKind -Text $r.Text)；$($r.Text.Trim())"
                }
                $tgtSize = (Get-Item -LiteralPath $tgtTmp).Length
                $tgtSha = (Get-FileHash -LiteralPath $tgtTmp -Algorithm SHA256).Hash.ToLower()
                if ($tgtSize -ne $it.ExpectedSize -or $tgtSha -ne $it.ExpectedSha) {
                    throw "TARGET_CONFLICT：已存在目标 SHA/大小不一致，不覆盖"
                }
                $record.CopyStatus = 'IDEMPOTENT_SKIP'
                Write-Host "目标已存在且校验一致，幂等跳过"
            }
            else {
                if (-not $Execute) {
                    $record.CopyStatus = 'DRY_RUN_PLAN'
                    Write-Host "[DRY RUN] 证据通过后将原子条件创建 $($it.TargetKey)"
                }
                else {
                    # 3) 原子条件写：仅 Execute 可达，捕获真实错误码，412 不覆盖
                    $r = Invoke-Aws -Arguments @(
                        's3api','put-object','--endpoint-url',$EndpointUrl,'--region',$Region,
                        '--bucket',$Bucket,'--key',$it.TargetKey,'--if-none-match','*',
                        '--body',$cached.Tmp,'--content-type','application/pdf'
                    )
                    if ($r.ExitCode -ne 0) {
                        throw "CONDITIONAL_PUT_FAILED:$(Get-AwsErrorKind -Text $r.Text)；$($r.Text.Trim())"
                    }
                    $record.CopyStatus = 'CREATED'
                    Write-Host "已原子条件创建 appId=$($it.AppId)，请运行 verify_target_objects.ps1"
                }
            }
        }
        catch {
            # 真实错误码与完整摘要写入 Error（不含密钥）
            $record.Error = "$($_.Exception.GetType().Name): $($_.Exception.Message)"
            $stopLoop = $true
            Write-Host "appId=$($it.AppId) 失败：$($record.Error)"
        }
        finally {
            $results.Add($record)
        }
    }
}
finally {
    if ($null -eq $prevAk) { Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue }
    else { $env:AWS_ACCESS_KEY_ID = $prevAk }
    if ($null -eq $prevSk) { Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue }
    else { $env:AWS_SECRET_ACCESS_KEY = $prevSk }
    if ($null -eq $prevNoProxy) { Remove-Item Env:NO_PROXY -ErrorAction SilentlyContinue }
    else { $env:NO_PROXY = $prevNoProxy }
    if ($null -eq $prevNoProxyLower) { Remove-Item Env:no_proxy -ErrorAction SilentlyContinue }
    else { $env:no_proxy = $prevNoProxyLower }

    foreach ($tp in $tempFiles) {
        Remove-Item -LiteralPath $tp -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $skInput) { $skInput.Dispose() }
    $skInput = $null
    $akInput = $null

    if ($results.Count -gt 0) {
        $results | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8
        Write-Host "报告已独占保存：$ReportPath（未记录凭据）"
    }
}

Write-Host "复制脚本结束：未连接数据库、未执行 SQL、未删除对象"
