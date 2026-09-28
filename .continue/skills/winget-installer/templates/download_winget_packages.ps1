#Requires -Version 5.1
<#
.SYNOPSIS
  Download winget packages as offline installers (msi/exe/msix bundles).
.DESCRIPTION
  Reads packages from default-packages.json (same directory), resolves the
  latest installer URL via the winget-pkgs manifest API (GitHub), and downloads
  installers into the script's own directory. Already-downloaded files are
  skipped. Requires only PowerShell 5.1+ (no winget needed on the download
  machine); internet access required.
.PARAMETER Config
  Path to the packages JSON config. Default: default-packages.json next to script.
.PARAMETER OutDir
  Output directory. Default: script directory.
.EXAMPLE
  .\download_winget_packages.ps1
  .\download_winget_packages.ps1 -Config my.json -OutDir D:\offline
#>
param(
    [string]$Config = (Join-Path $PSScriptRoot 'default-packages.json'),
    [string]$OutDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $Config)) { throw "Config not found: $Config" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$packages = (Get-Content $Config -Raw | ConvertFrom-Json).packages

function Get-LatestVersion([string]$PackageId) {
    # Resolve latest version from winget-pkgs repo via GitHub API
    $api = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/" +
           ($PackageId[0]) + "/" + ($PackageId -replace '\.', '/')
    $headers = @{ 'User-Agent' = 'winget-offline-downloader' }
    if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    $items = Invoke-RestMethod -Uri $api -Headers $headers
    $versions = @($items | Where-Object { $_.name -match '^\d+(\.\d+)*(\-[\w.]+)?$' } |
        ForEach-Object { $_.name })
    if (-not $versions) { throw "No versions found for $PackageId" }
    # naive sort; good enough for most packages
    return ($versions | Sort-Object { [version]($_ -replace '-.*$', '') } -ErrorAction SilentlyContinue)[-1]
}

function Get-InstallerUrl([string]$PackageId, [string]$Version) {
    $base = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/" +
            ($PackageId[0]) + "/" + ($PackageId -replace '\.', '/') + "/$Version"
    $headers = @{ 'User-Agent' = 'winget-offline-downloader' }
    # try locale variants of the installer manifest
    foreach ($suffix in @('installer.yaml', 'zh-CN.installer.yaml', 'en-US.installer.yaml')) {
        try {
            $yaml = (Invoke-WebRequest -Uri "$base/$suffix" -Headers $headers -UseBasicParsing).Content
            break
        } catch { continue }
    }
    if (-not $yaml) { throw "Installer manifest not found for $PackageId $Version" }
    # collect InstallerUrl entries
    $urls = [regex]::Matches($yaml, 'InstallerUrl:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value }
    if (-not $urls) { throw "No InstallerUrl in manifest for $PackageId $Version" }
    # prefer x64 exe/msi, then any
    $pick = $urls | Where-Object { $_ -match 'x64' -and $_ -match '\.(exe|msi|msix|msixbundle|zip)$' } | Select-Object -First 1
    if (-not $pick) { $pick = $urls | Where-Object { $_ -match '\.(exe|msi|msix|msixbundle)$' } | Select-Object -First 1 }
    if (-not $pick) { $pick = $urls[0] }
    return $pick
}

foreach ($pkg in $packages) {
    $id = $pkg.id
    Write-Host "==> Processing $id ..." -ForegroundColor Cyan
    try {
        $version = Get-LatestVersion $id
        Write-Host "    latest version: $version"
        $url = Get-InstallerUrl $id $version
        $fileName = ($id -replace '\.', '_') + "-$version-" + [IO.Path]::GetFileName($url)
        $outFile = Join-Path $OutDir $fileName
        if (Test-Path $outFile) {
            Write-Host "    [SKIP] already downloaded: $fileName" -ForegroundColor Yellow
        } else {
            Write-Host "    downloading: $url"
            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
            Write-Host "    [OK] saved to $outFile" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [FAIL] $id : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone. Offline installers are in: $OutDir"
Write-Host "Run install_winget_offline.ps1 on the target machine to install them."
