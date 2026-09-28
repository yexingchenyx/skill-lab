#Requires -Version 5.1
<#
.SYNOPSIS
  Offline-install winget packages from locally downloaded installers,
  falling back to `winget install` for anything missing.
.DESCRIPTION
  Reads packages from default-packages.json (same directory). For each
  package: if a matching installer file exists next to the script, run it
  silently; otherwise try `winget install --id <id>` (requires network).
  Run as Administrator on the target machine.
.PARAMETER Config
  Path to the packages JSON config. Default: default-packages.json next to script.
.EXAMPLE
  .\install_winget_offline.ps1
#>
param(
    [string]$Config = (Join-Path $PSScriptRoot 'default-packages.json')
)

$ErrorActionPreference = 'Continue'
if (-not (Test-Path $Config)) { throw "Config not found: $Config" }
$packages = (Get-Content $Config -Raw | ConvertFrom-Json).packages

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    Write-Warning "Not running as Administrator — some installs may fail. Right-click PowerShell -> Run as Administrator."
}

function Test-Installed([string]$Id) {
    # winget list check (works even without network for installed query)
    $out = & winget list --id $Id --exact 2>$null
    return ($LASTEXITCODE -eq 0 -and $out -match [regex]::Escape($Id))
}

foreach ($pkg in $packages) {
    $id = $pkg.id
    Write-Host "==> Installing $id ..." -ForegroundColor Cyan

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try { if (Test-Installed $id) { Write-Host "    [SKIP] already installed" -ForegroundColor Yellow; continue } } catch {}
    }

    # find a local installer file: <id with dots as _>-*
    $pattern = ($id -replace '\.', '_') + '-*'
    $installer = Get-ChildItem -Path $PSScriptRoot -Filter $pattern -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1

    if ($installer) {
        Write-Host "    offline install: $($installer.Name)"
        $ext = $installer.Extension.ToLower()
        switch ($ext) {
            '.msi' {
                $args = @('/i', "`"$($installer.FullName)`"", '/norestart')
                if ($pkg.override) { $args += $pkg.override -split ' ' }
                Start-Process msiexec.exe -ArgumentList $args -Wait
            }
            '.exe' {
                $args = @('/S', '/silent', '/quiet', '/verysilent', '/norestart')
                Start-Process $installer.FullName -ArgumentList $args -Wait
            }
            default {
                Write-Host "    [WARN] unsupported installer type '$ext', opening interactively" -ForegroundColor Yellow
                Start-Process $installer.FullName -Wait
            }
        }
        Write-Host "    [OK] done" -ForegroundColor Green
    }
    elseif (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "    no local installer, falling back to winget install"
        $wingetArgs = @('install', '--id', $id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements')
        if ($pkg.override) { $wingetArgs += @('--override', $pkg.override) }
        & winget @wingetArgs
        if ($LASTEXITCODE -eq 0) { Write-Host "    [OK] installed via winget" -ForegroundColor Green }
        else { Write-Host "    [FAIL] winget exit code $LASTEXITCODE" -ForegroundColor Red }
    }
    else {
        Write-Host "    [FAIL] no local installer and winget not available" -ForegroundColor Red
    }
}

Write-Host "`nAll done."
