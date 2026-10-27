$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendRoot = Split-Path -Parent $scriptRoot
$environmentRoot = Join-Path $env:LOCALAPPDATA 'CAppMemoryEmbedding'
$python = Get-Command python -ErrorAction Stop
$venvPython = Join-Path $environmentRoot 'Scripts\python.exe'
$installedMarker = Join-Path $environmentRoot '.fastembed-installed'

if (-not (Test-Path -LiteralPath $venvPython)) {
    & $python.Source -m venv $environmentRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the local embedding environment.' }
}

if (-not (Test-Path -LiteralPath $installedMarker)) {
    & $venvPython -m pip install -r (Join-Path $scriptRoot 'requirements-memory.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Could not install FastEmbed. Check the configured Python package index.' }
    New-Item -ItemType File -Force -Path $installedMarker | Out-Null
}

$env:MEMORY_EMBEDDING_HOST = '127.0.0.1'
$env:MEMORY_EMBEDDING_PORT = '8091'
& $venvPython (Join-Path $scriptRoot 'memory_embedding_service.py')
