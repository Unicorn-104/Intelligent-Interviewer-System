# 条件写能力探测脚本（仅生成，本轮禁止执行）
# 默认 Dry Run，不写任何对象；只有 -Execute 才对非生产探测 key 执行
# 验证：首次条件写成功、第二次同 key 条件写必须 412（409 不算成功）、GetObject 确认未覆盖且 SHA 一致
# 全部满足才生成正式证据 JSON；版本无法自动获取，须人工核验并保持 MANUAL_VERIFICATION
# 探测对象清理单独授权（-CleanupProbe），默认不删除，绝不操作正式业务 PDF
# 兼容 Windows PowerShell 5.1 与 pwsh 7

param(
    [switch]$Execute,
    [switch]$CleanupProbe,
    [string]$EndpointUrl = "http://127.0.0.1:19000",
    [string]$Bucket = "recruit-files",
    [string]$Region = "us-east-1",
    [string]$EvidencePath = "conditional_write_evidence.json",
    [string]$RustfsVersion = "",
    [string]$ProbeKey = ""
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "未找到 aws CLI"
}
# 证据文件独占创建，不覆盖
if (Test-Path -LiteralPath $EvidencePath) {
    throw "证据文件已存在：$EvidencePath，请指定新路径，不覆盖不删除。"
}

# 独立探测 key：固定前缀 + 随机后缀，禁止使用正式业务对象 key
if ([string]::IsNullOrWhiteSpace($ProbeKey)) {
    $ProbeKey = "conditional-write-probe/probe-" + [GUID]::NewGuid().ToString("N") + ".txt"
}
if ($ProbeKey -notlike 'conditional-write-probe/*') {
    throw "探测 key 必须位于 conditional-write-probe/ 前缀，拒绝执行：$ProbeKey"
}

# 从 AWS CLI 输出解析错误码
function Get-AwsErrorKind {
    param([string]$Text)
    if ($Text -match 'PreconditionFailed' -or $Text -match '412') { return 'HTTP_412_PRECONDITION_FAILED' }
    if ($Text -match 'Conflict' -or $Text -match '409') { return 'HTTP_409_CONFLICT' }
    if ($Text -match 'AccessDenied' -or $Text -match '403') { return 'HTTP_403_ACCESS_DENIED' }
    if ($Text -match '5[0-9][0-9]') { return 'HTTP_5XX_SERVER_ERROR' }
    return 'NETWORK_OR_UNKNOWN'
}

# 凭据初始化
$skInput = $null
$prevAk = $null
$prevSk = $null
$prevNoProxy = $null
$prevNoProxyLower = $null
$probeTmp = [IO.Path]::GetTempFileName()
$readTmp = [IO.Path]::GetTempFileName()
$probePass = $false
$firstPutStatus = 'NOT_VERIFIED'
$secondPutStatus = 'NOT_VERIFIED'
$firstSha = 'NOT_VERIFIED'
$finalSha = 'NOT_VERIFIED'

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

    if (-not $Execute) {
        Write-Host "[DRY RUN] 不执行写入。计划探测 key=$ProbeKey：首次条件写、第二次预期 412、读取校验 SHA"
    }
    else {
        # 准备探测内容并计算首次 SHA
        $payload = "conditional-write-probe " + [GUID]::NewGuid().ToString("N")
        [IO.File]::WriteAllText($probeTmp, $payload, (New-Object System.Text.UTF8Encoding($false)))
        $firstSha = (Get-FileHash -LiteralPath $probeTmp -Algorithm SHA256).Hash.ToLower()

        # 第一次条件写：必须成功
        aws s3api put-object --endpoint-url $EndpointUrl --region $Region `
            --bucket $Bucket --key $ProbeKey --if-none-match "*" --body $probeTmp *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "首次条件写未成功，探测失败，不生成证据"
        }
        $firstPutStatus = 'HTTP_200_OK'

        # 第二次同 key 条件写：必须 412
        $secondOut = aws s3api put-object --endpoint-url $EndpointUrl --region $Region `
            --bucket $Bucket --key $ProbeKey --if-none-match "*" --body $probeTmp 2>&1
        $secondPutStatus = Get-AwsErrorKind -Text ($secondOut | Out-String)
        if ($secondPutStatus -ne 'HTTP_412_PRECONDITION_FAILED') {
            # 409 或其他结果均不算成功
            throw "第二次条件写结果为 $secondPutStatus，不是 412，条件写能力验证失败，不生成证据"
        }

        # GetObject 读取，确认内容未被覆盖
        aws s3api get-object --endpoint-url $EndpointUrl --region $Region `
            --bucket $Bucket --key $ProbeKey $readTmp *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "探测对象读取失败，不生成证据"
        }
        $finalSha = (Get-FileHash -LiteralPath $readTmp -Algorithm SHA256).Hash.ToLower()
        if ($finalSha -ne $firstSha) {
            throw "首次与最终 SHA 不一致，疑似发生覆盖，验证失败"
        }
        $probePass = $true
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

    Remove-Item -LiteralPath $probeTmp -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $readTmp -Force -ErrorAction SilentlyContinue
    if ($null -ne $skInput) { $skInput.Dispose() }
    $skInput = $null
    $akInput = $null
}

# 探测全部通过才生成正式证据（独占，不覆盖）
if ($Execute -and $probePass) {
    $versionValue = if ([string]::IsNullOrWhiteSpace($RustfsVersion)) { 'NOT_VERIFIED' } else { $RustfsVersion }
    $evidence = [pscustomobject]@{
        endpoint = $EndpointUrl
        bucket = $Bucket
        region = $Region
        rustfsVersion = $versionValue
        versionVerification = 'MANUAL_VERIFICATION'
        probeKey = $ProbeKey
        firstPutStatus = $firstPutStatus
        secondPutStatus = $secondPutStatus
        firstObjectSha256 = $firstSha
        finalObjectSha256 = $finalSha
        verifiedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
        verifiedBy = 'NOT_VERIFIED'
        result = if ($versionValue -eq 'NOT_VERIFIED') { 'NOT_VERIFIED' } else { 'VERIFIED' }
    }
    $json = $evidence | ConvertTo-Json -Depth 3
    [IO.File]::WriteAllText($EvidencePath, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "证据已生成：$EvidencePath（result=$($evidence.result)）"
    if ($versionValue -eq 'NOT_VERIFIED') {
        Write-Host "提示：rustfsVersion 待人工核验补填，补填并确认 verifiedBy 后证据才会被 copy_objects 接受。"
    }
}

# 探测对象清理：默认不执行；显式授权且校验前缀后仅删除该探测 key
if ($CleanupProbe) {
    if ($ProbeKey -notlike 'conditional-write-probe/*') {
        throw "清理中止：探测 key 前缀不合法"
    }
    aws s3api delete-object --endpoint-url $EndpointUrl --region $Region `
        --bucket $Bucket --key $ProbeKey *> $null
    if ($LASTEXITCODE -eq 0) { Write-Host "已清理探测对象：$ProbeKey" }
}
else {
    Write-Host "探测对象保留未删除（如需清理须显式 -CleanupProbe 授权）：$ProbeKey"
}
