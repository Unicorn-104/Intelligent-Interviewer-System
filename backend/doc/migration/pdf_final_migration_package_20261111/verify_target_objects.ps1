# 目标对象完整性验证脚本（最终安全收尾版）：仅验证 appId 70/71/78 的企业目标
# 完整 GetObject 读取并计算真实 SHA-256，不使用 ETag 代替
# GET_OBJECT_FAILED 记录具体错误类型；异常路径也清理临时 PDF
# 凭据环境变量在外层 finally 恢复；报告默认不覆盖
# 结果分类：PASS、GET_OBJECT_FAILED、SIZE_MISMATCH、SHA_MISMATCH
# 三条必须全部 PASS 才允许进入数据库回写审核；本脚本只读，不连接数据库
# 兼容 Windows PowerShell 5.1 与 pwsh 7

param(
    [string]$EndpointUrl = "http://127.0.0.1:19000",
    [string]$Bucket = "recruit-files",
    [string]$Region = "us-east-1",
    [string]$ReportPath = "target_verification_report.md"
)

$ErrorActionPreference = 'Stop'

# 报告默认不覆盖
if (Test-Path -LiteralPath $ReportPath) {
    throw "验证报告已存在：$ReportPath，请指定新的 -ReportPath，不覆盖不删除。"
}
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "未找到 aws CLI"
}

# 固定期望值
$items = @(
    [pscustomobject]@{
        AppId = 70
        TargetKey = 'enterprise-application-resume/1/70/f7265a2484e44f1bb8f28eb898e517d3.pdf'
        ExpectedSize = 309407
        ExpectedSha = 'd4da83f8d56c7b65e8a36cc5ed35d188cea66ec0c84e36243440e9b172230022'
    },
    [pscustomobject]@{
        AppId = 71
        TargetKey = 'enterprise-application-resume/1/71/41b70c7ec33e42be9bfbe584645935a0.pdf'
        ExpectedSize = 163683
        ExpectedSha = 'e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda'
    },
    [pscustomobject]@{
        AppId = 78
        TargetKey = 'enterprise-application-resume/1/78/18a5a19616884d64a492decd1f86a4e8.pdf'
        ExpectedSize = 163683
        ExpectedSha = 'e42eea0cbf46eba2dde87785099fd2b031e7fdf2cd2fe246b5f3631f85350bda'
    }
)

# 凭据与环境变量初始化
$skInput = $null
$prevAk = $null
$prevSk = $null
$prevNoProxy = $null
$prevNoProxyLower = $null
$rows = New-Object System.Collections.Generic.List[object]
$allPass = $true

# 把 get-object 失败输出归类为具体错误类型
function Get-GetObjectErrorKind {
    param([string]$Text)
    if ($Text -match '404' -or $Text -match 'NotFound' -or $Text -match 'NoSuchKey') {
        return '404_NOT_FOUND'
    }
    if ($Text -match '403' -or $Text -match 'AccessDenied' -or $Text -match 'Forbidden') {
        return '403_ACCESS_DENIED'
    }
    if ($Text -match '5[0-9][0-9]') {
        return '5XX_SERVER_ERROR'
    }
    return 'NETWORK_OR_UNKNOWN'
}

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

    foreach ($it in $items) {
        Write-Host "--- 验证 appId=$($it.AppId) ---"
        $tmp = [IO.Path]::GetTempFileName()
        $resultType = 'PASS'
        $errorDetail = ''
        $actualSize = $null
        $actualSha = $null

        try {
            # 捕获输出以便失败时解析具体错误类型
            $captured = aws s3api get-object --endpoint-url $EndpointUrl --region $Region `
                --bucket $Bucket --key $it.TargetKey $tmp 2>&1
            if ($LASTEXITCODE -ne 0) {
                $resultType = 'GET_OBJECT_FAILED'
                $errorDetail = Get-GetObjectErrorKind -Text ($captured | Out-String)
                $allPass = $false
            }
            else {
                # 基于完整字节计算真实 SHA-256，不读取 ETag
                $actualSize = (Get-Item -LiteralPath $tmp).Length
                $actualSha = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLower()
                if ($actualSize -ne $it.ExpectedSize) {
                    $resultType = 'SIZE_MISMATCH'
                    $errorDetail = "expected=$($it.ExpectedSize) actual=$actualSize"
                    $allPass = $false
                }
                elseif ($actualSha -ne $it.ExpectedSha) {
                    $resultType = 'SHA_MISMATCH'
                    $errorDetail = "expected=$($it.ExpectedSha) actual=$actualSha"
                    $allPass = $false
                }
            }
        }
        catch {
            # 计算/读取阶段抛异常：归类为失败并保留异常类型，不使脚本静默
            $resultType = 'GET_OBJECT_FAILED'
            $errorDetail = "$($_.Exception.GetType().Name): $($_.Exception.Message)"
            $allPass = $false
        }
        finally {
            # 异常路径也保证清理临时 PDF
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }

        $rows.Add([pscustomobject]@{
            AppId = $it.AppId
            TargetKey = $it.TargetKey
            Result = $resultType
            ErrorDetail = $errorDetail
            ExpectedSize = $it.ExpectedSize
            ActualSize = $actualSize
            ExpectedSha = $it.ExpectedSha
            ActualSha = $actualSha
        })
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

    if ($null -ne $skInput) { $skInput.Dispose() }
    $skInput = $null
    $akInput = $null
}

# 生成独立验证报告（独占创建，且不含凭据）
$verifyTime = Get-Date
$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("# 目标对象完整性验证报告")
[void]$report.AppendLine("")
[void]$report.AppendLine("- Endpoint：$EndpointUrl")
[void]$report.AppendLine("- Bucket：$Bucket")
[void]$report.AppendLine("- Region：$Region")
[void]$report.AppendLine("- 验证时间：$($verifyTime.ToString('yyyy-MM-dd HH:mm:ss zzz'))")
[void]$report.AppendLine("")
[void]$report.AppendLine("验证方式：完整 GetObject 读取并计算真实 SHA-256，未使用 ETag")
[void]$report.AppendLine("")
[void]$report.AppendLine("| appId | TargetKey | 结果 | 错误明细 | 期望大小 | 实际大小 | 期望 SHA | 实际 SHA |")
[void]$report.AppendLine("|---|---|---|---|---|---|---|---|")
foreach ($r in $rows) {
    [void]$report.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} |" -f `
        $r.AppId, $r.TargetKey, $r.Result, $r.ErrorDetail,
        $r.ExpectedSize, $r.ActualSize, $r.ExpectedSha, $r.ActualSha))
}
[void]$report.AppendLine("")
if ($allPass) {
    [void]$report.AppendLine("总体结论：三条结果均为 PASS，允许进入数据库回写审核。")
} else {
    [void]$report.AppendLine("总体结论：存在非 PASS 项，禁止进入数据库回写。")
}
[IO.File]::WriteAllText($ReportPath, $report.ToString(), (New-Object System.Text.UTF8Encoding($false)))

if (-not $allPass) {
    throw "目标完整性验证未全部 PASS，已阻断数据库回写，报告见 $ReportPath"
}
Write-Host "验证全部 PASS，报告已保存：$ReportPath"
