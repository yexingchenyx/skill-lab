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

# winget-pkgs manifest path: first letter of the package id is LOWERCASE in the
# repo directory structure (e.g. Git.Git -> manifests/g/Git/Git), and the rest
# of the id maps dots to path segments. GitHub tree URLs are case-sensitive.
function Get-ManifestDir([string]$PackageId) {
    return ($PackageId.Substring(0,1).ToLower()) + "/" + ($PackageId -replace '\.', '/')
}

function Get-LatestVersion([string]$PackageId) {
    # Resolve latest version from winget-pkgs repo.
    # Method 1 (preferred, no rate limit): scrape the GitHub tree HTML page
    $dir = Get-ManifestDir $PackageId
    $treeUrl = "https://github.com/microsoft/winget-pkgs/tree/master/manifests/" + $dir
    try {
        $resp = Invoke-WebRequest -Uri $treeUrl -Headers @{ 'User-Agent' = 'Mozilla/5.0' } -UseBasicParsing
        $bytes = $resp.RawContentStream.ToArray()
        $html = if ($bytes) { [Text.Encoding]::UTF8.GetString($bytes) } else { $resp.Content }
        $prefix = "manifests/" + $dir + "/"
        $versions = [regex]::Matches($html, [regex]::Escape($prefix) + '(\d+(?:\.\d+)*(?:-[\w.]+)?)') |
            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
        if ($versions) {
            return ($versions | Sort-Object { [version]($_ -replace '-.*$', '') })[-1]
        }
    } catch { Write-Host "    [WARN] HTML scrape failed ($($_.Exception.Message)), trying API fallback" -ForegroundColor Yellow }

    # Method 2 (fallback): GitHub contents API (rate limited: 60/hr anonymous, 5000/hr with token)
    $api = "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/" + $dir
    $headers = @{ 'User-Agent' = 'winget-offline-downloader' }
    if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    $items = Invoke-RestMethod -Uri $api -Headers $headers
    $versions = @($items | Where-Object { $_.name -match '^\d+(\.\d+)*(\-[\w.]+)?$' } |
        ForEach-Object { $_.name })
    if (-not $versions) { throw "No versions found for $PackageId" }
    return ($versions | Sort-Object { [version]($_ -replace '-.*$', '') })[-1]
}

function Get-InstallerUrl([string]$PackageId, [string]$Version) {
    $base = "https://raw.githubusercontent.com/microsoft/winget-pkgs/master/manifests/" +
            (Get-ManifestDir $PackageId) + "/$Version"
    $headers = @{ 'User-Agent' = 'winget-offline-downloader' }
    # try installer manifest: newer manifests are named "<Id>.installer.yaml",
    # older ones just "installer.yaml"; also try locale variants
    $leaf = $PackageId -replace '.*\.', ''
    $suffixes = @("$PackageId.installer.yaml", 'installer.yaml', "$leaf.installer.yaml",
                  "$PackageId.locale.zh-CN.installer.yaml", "$PackageId.locale.en-US.installer.yaml",
                  'zh-CN.installer.yaml', 'en-US.installer.yaml') | Select-Object -Unique
    foreach ($suffix in $suffixes) {
        try {
            $resp = Invoke-WebRequest -Uri "$base/$suffix" -Headers $headers -UseBasicParsing
            # decode as UTF8 explicitly: .Content may be a byte[] or mis-decoded string
            $bytes = $resp.RawContentStream.ToArray()
            if ($bytes) { $yaml = [Text.Encoding]::UTF8.GetString($bytes) } else { $yaml = $resp.Content }
            break
        } catch { continue }
    }
    if (-not $yaml) { throw "Installer manifest not found for $PackageId $Version" }
    # collect InstallerUrl entries
    $urls = [regex]::Matches($yaml, 'InstallerUrl:\s*(\S+)') | ForEach-Object { $_.Groups[1].Value }
    if (-not $urls) { throw "No InstallerUrl in manifest for $PackageId $Version" }
    # prefer x64 exe/msi (most reliable for offline silent install), then
    # x64 msix/msixbundle, then any exe/msi, then any msix, then x64 zip
    # (portable, e.g. Snipaste/uv/x64dbg), then anything else
    $pick = $urls | Where-Object { $_ -match 'x64|x86_64' -and $_ -notmatch 'i386|arm64|aarch64' -and $_ -match '\.(exe|msi)$' } | Select-Object -First 1
    if (-not $pick) { $pick = $urls | Where-Object { $_ -match 'x64' -and $_ -match '\.(msix|msixbundle)$' } | Select-Object -First 1 }
    if (-not $pick) { $pick = $urls | Where-Object { $_ -match '\.(exe|msi)$' } | Select-Object -First 1 }
    if (-not $pick) { $pick = $urls | Where-Object { $_ -match '\.(msix|msixbundle)$' } | Select-Object -First 1 }
    if (-not $pick) { $pick = $urls | Where-Object { $_ -match 'x64|x86_64' -and $_ -notmatch 'i386|arm64|aarch64' -and $_ -match '\.zip$' } | Select-Object -First 1 }
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
