# Automated Regression Test Runner (PowerShell)
# Usage: .\scripts\run_regression.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

Write-Host "Triggering Ascon RTL Project Regression..." -ForegroundColor Cyan
python "$RootDir\scripts\run_regression.py" @args
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nRegression FAILED with exit code $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
} else {
    Write-Host "`nRegression PASSED successfully." -ForegroundColor Green
    exit 0
}
