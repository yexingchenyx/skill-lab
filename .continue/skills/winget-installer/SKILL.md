---
name: winget-installer
description: Download Windows software as offline installers via winget manifests (download script) and generate an offline install script for the target machine. Default package list includes Git, Python, CMake, the MSVC C++ build environment, Snipaste, Sourcetree, Everything, FastStone Image Viewer, Google Chrome, VS Code, uv, KiCad, FreeCAD, Zotero, Foxit PDF Reader, PotPlayer, x64dbg, WSL2, Windows Terminal, and Tabby.
---

# Winget Offline Installer

Download offline installers for a Windows software list (via the
`microsoft/winget-pkgs` manifest API) and produce a script to install them
offline on a target machine.

## When to use
- User asks to download Windows software installers for offline installation
- User wants to set up a dev environment (Git / Python / CMake / C++) on a
  machine without network access

## Inputs — ask the user first (suggest defaults)
- Package list (optional) — if the user doesn't specify, use the **default
  set: Git, Python 3, CMake, Visual Studio 2022 Build Tools (C++ 编译环境),
  Snipaste, Sourcetree, Everything, FastStone Image Viewer, Google Chrome,
  VS Code, uv, KiCad, FreeCAD, Zotero, Foxit PDF Reader, PotPlayer, x64dbg,
  WSL2, Windows Terminal, Tabby**
  from the bundled template `templates/default-packages.json` (relative to
  this skill's directory); otherwise use the user's list (winget package ids,
  e.g. `Notepad++.Notepad++`)
- Output directory (default: `./.cache/winget-offline`)

## Step 1 — Prepare the output directory

```bash
mkdir -p ./.cache/winget-offline
cp <skill-dir>/templates/download_winget_packages.ps1 ./.cache/winget-offline/
cp <skill-dir>/templates/install_winget_offline.ps1 ./.cache/winget-offline/
cp <skill-dir>/templates/default-packages.json ./.cache/winget-offline/
```

If the user specified a package list, update the copied
`default-packages.json` (keys: `packages`, each with `id`, `name`, optional
`override` for custom installer arguments) instead of editing the scripts.

### Default package set
- `Git.Git` — Git
- `Python.Python.3.12` — Python 3.12
- `Kitware.CMake` — CMake
- `Microsoft.VisualStudio.2022.BuildTools` — VS 2022 Build Tools with the
  `Microsoft.VisualStudio.Workload.VCTools` workload (C++ 编译环境), via the
  `override` field
- `liule.Snipaste` — Snipaste 截图工具
- `Atlassian.Sourcetree` — Sourcetree Git 客户端
- `voidtools.Everything` — Everything 文件搜索
- `FastStone.Viewer` — FastStone Image Viewer 看图软件
- `Google.Chrome` — Google Chrome 浏览器
- `Microsoft.VisualStudioCode` — Visual Studio Code 编辑器
- `astral-sh.uv` — uv（Python 环境管理工具）
- `KiCad.KiCad` — KiCad（EDA/PCB 设计）
- `FreeCAD.FreeCAD` — FreeCAD（3D 建模/CAD）
- `DigitalScholar.Zotero` — Zotero（文献管理）
- `Foxit.FoxitReader` — Foxit PDF Reader（PDF 阅读）
- `Daum.PotPlayer` — PotPlayer（视频播放器）
- `x64dbg.x64dbg` — x64dbg（Windows 调试器）
- `Microsoft.WSL` — WSL2（Windows Subsystem for Linux，需 Win10 19044+/Win11）
- `Microsoft.WindowsTerminal` — Windows Terminal（微软官方终端）
- `Eugeny.Tabby` — Tabby 终端（含 SSH 管理）

Edit `default-packages.json` to change the default list — do not hardcode it
in SKILL.md.

## Step 2 — Download (on a machine with internet)

**IMPORTANT — do NOT run the download yourself.** Hand the scripts to the
user to review and run manually.

```powershell
cd .\.cache\winget-offline
.\download_winget_packages.ps1            # optional: -Config my.json -OutDir D:\offline
```

The download script:
- resolves the latest version by scraping the winget-pkgs GitHub tree page
  (**no API rate limit**); falls back to the GitHub contents API if scraping
  fails (set `GITHUB_TOKEN` to raise the API limit to 5000/hr)
- NOTE: the manifest path's first letter is lowercase (`Git.Git` ->
  `manifests/g/Git/Git`) and GitHub tree URLs are case-sensitive
- tries installer manifest names `<Id>.installer.yaml`, `installer.yaml`,
  `<leaf>.installer.yaml`, then locale variants
- picks the x64 exe/msi installer URL from the installer manifest (falls back
  to x64 msixbundle, then any exe/msi, then x64 zip for portable apps)
- skips already-downloaded files (`[SKIP]`); delete the file to force
  re-download
- saves installers next to the script, named `{id}-{version}-{filename}`
- needs only PowerShell 5.1+ (winget itself is NOT required on the
  download machine)

## Step 3 — Offline install (on the target machine)

Copy the whole output directory (scripts + installers + json) to the target
machine, then run in an **Administrator** PowerShell:

```powershell
.\install_winget_offline.ps1
```

The install script:
- skips packages already installed (checked via `winget list` when available)
- installs `.msi` via `msiexec /i ... /norestart`, `.exe` with common
  silent switches (`/S /silent /quiet /verysilent /norestart`),
  `.msix`/`.msixbundle` via `Add-AppxPackage`, and `.zip` portable apps
  extracted to a `Tools\` subfolder; anything else is opened interactively
- applies the package's `override` arguments (e.g. the VS Build Tools
  workload selection)
- falls back to `winget install --id <id> --exact --silent` if no local
  installer exists (requires network + winget on the target)

## Step 4 — Report

Tell the user:
- paths of the copied scripts and config in the output directory
- how to run the download script (Step 2) and the install script (Step 3)
- that already-downloaded/already-installed packages are skipped
- that the VS Build Tools download is large (~several GB) and its installer
  needs the `override` workload args to actually include the C++ toolchain

Do not run either script yourself.
