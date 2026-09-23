---
name: vscode-extensions
description: Download offline .vsix install packages for VS Code extensions from the Marketplace, matched to the local VS Code version and OS/arch, into ./.cache/vscode-extensions-download
---

# Download VS Code Extension Offline Packages

Download `.vsix` offline installers for VS Code extensions from the
Marketplace, matched to the local VS Code version and OS/architecture.

## When to use
- User asks to download offline/offline-install (.vsix) packages for VS Code extensions
- User wants to install extensions on a machine without Marketplace access

## Inputs — ask the user first (suggest config defaults)
- VS Code version (required, e.g. `1.85.2`) — the user must specify it
- Target OS/arch (required, e.g. `linux-x64`) — the user must specify it
- Extension list (optional) — if the user doesn't specify any, use the
  **default set of Microsoft C/C++, Python, Notebook, Markdown extensions + Vim**
  from the bundled template `templates/default-extensions.json` (relative to
  this skill's directory); otherwise download the user's list (they can also
  say "C++ defaults + X, Y" to combine)
- Output directory (default: `./.cache/vscode-extensions-download`)

If the bundled config template already has `vscodeVersion`/`targetPlatform`,
offer those as the default suggestion and only ask for confirmation instead
of asking open-ended questions.

### Default extension set (Microsoft C/C++, Python, Notebook, Markdown & Vim)

The default list lives in the bundled template
`templates/default-extensions.json` (relative to this skill's directory).
It contains:
- `extensions`: the default extension ids to download
- `platformSpecific`: ids that require a `targetPlatform` parameter

Edit that file to change the default list — do not hardcode it in SKILL.md.
See the template file for the current set of default extensions.

Notes:
- `ms-python.python` and `ms-toolsai.jupyter` are platform-specific — always
  pass `targetPlatform`. `ms-python.vscode-pylance` and `ms-python.debugpy`
  may also have platform variants; follow the 404-retry rule (step 2).
- `twbs.cmake` is the maintained fork of the deprecated `ms-vscode.cmake`;
  prefer it unless the user explicitly asks for the old one.
- Other extensions may be universal (no platform variants), but still
  follow the 404-retry rule (step 2) for each.

Do NOT auto-detect the local environment: the packages are usually meant for
another machine, so always ask for the VS Code version and target platform
explicitly (offer the platform table below as choices). Only use the values
the user provides.

## Step 1 — Map the user's OS/arch to targetPlatform

(No local detection — use only the user-specified values. Reference table:)

Map to the Marketplace `targetPlatform` value:

| System                          | targetPlatform                  |
|---------------------------------|---------------------------------|
| Linux x64                       | `linux-x64`                     |
| Linux arm64                     | `linux-arm64`                   |
| Linux armhf (32-bit)            | `linux-armhf`                   |
| Linux alpine x64                | `alpine-x64`                    |
| Linux alpine arm64              | `alpine-arm64`                  |
| macOS Intel                     | `darwin-x64`                    |
| macOS Apple Silicon             | `darwin-arm64`                  |
| Windows x64                     | `win32-x64`                     |
| Windows arm64                   | `win32-arm64`                   |
| Universal / no platform variant | omit the `targetPlatform` param |

Notes:
- Platform-specific extensions (e.g. ms-vscode.cpptools, ms-python.python,
  ms-dotnettools.csharp) REQUIRE the correct `targetPlatform`.
- Pure JS/TS extensions often have no platform variants — omit the param.
- If unsure whether a platform variant exists, first try WITH
  `targetPlatform`; on 404 retry without it.
- VS Code version matters for `engines.vscode` compatibility: Marketplace
  serves the latest compatible version by default. To pin, use the
  version-specific URL form (step 2, variant B). Compatibility is checked
  against the **user-specified** VS Code version, not the local one.

## Step 2 — Download

Create the output dir: `mkdir -p ./.cache/vscode-extensions-download`

**IMPORTANT — do NOT run the download yourself.** Copy the bundled script
template `templates/download_vscode_extensions.py` (relative to this skill's
directory) to the output directory and let the user review/edit and run it
manually. Do not write the script inline in SKILL.md or regenerate it from
scratch — the template is the single source of truth.

Also copy the config template `templates/default-extensions.json` to
`./.cache/vscode-extensions-download/default-extensions.json` (keys:
`vscodeVersion`, `targetPlatform`, `extensions`, `platformSpecific`) so the
user can edit the list without touching the script. If the user specified a
version/platform/extension list, update the copied config accordingly instead
of editing the script.

The template script already provides:
- config read from the JSON file (version, platform, extension list)
- CLI overrides: `--vscode`, `--platform`, `--config`, plus positional
  extension ids
- **skip already-downloaded extensions**: scans the output directory for
  existing `{id}-{version}[-platform].vsix` files and skips those ids
  (prints `[SKIP]`); deleting the file forces a re-download
- latest-version resolution compatible with the target VS Code version
  (`engines.vscode` check) and download via the asset API below
- 404 retry without `targetPlatform` (universal build)
- download into the script's own directory
- **bypass system proxy env vars by default** (e.g. `socks5://` proxies, which
  Python's urllib cannot handle and cause SSL/connection errors). Opt out with
  `VSIX_USE_PROXY=1` if a proxy is needed

Use the Marketplace asset API (reference for how the template script works,
or as a manual fallback if the user asks for direct download commands). Two
URL forms:

**A. Latest compatible version (default):**
```
https://{publisher}.gallery.vsassets.io/_apis/public/gallery/publisher/{publisher}/extension/{extension}/{version}/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage?targetPlatform={platform}
```
When you don't know the version, first resolve it:
```bash
curl -s "https://marketplace.visualstudio.com/items?itemName={publisher}.{extension}" \
  | grep -oP 'Unique/Version/\d+\.\d+\.\d+' | head -1
```
or query the gallery API:
```bash
curl -s -X POST 'https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery' \
  -H 'Content-Type: application/json' -H 'Accept: application/json;api-version=3.0-preview.1' \
  -d '{"filters":[{"criteria":[{"filterType":7,"value":"{publisher}.{extension}"}]}],"flags":914}' \
  | grep -oP '"version":"\K[^"]+' | head -1
```

**B. Pinned version (version-specific, respects `engines.vscode`):**
```
https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{extension}/{version}/vspackage?targetPlatform={platform}
```
Check compatibility: the extension's `engines.vscode` range must include the
local VS Code version (e.g. `^1.80.0` matches 1.138.0; `^1.90.0` does NOT
match 1.80.0). If incompatible, either pick an older extension version or
warn the user.

**Download command:**
```bash
curl -L -o "./.cache/vscode-extensions-download/{publisher}.{extension}-{version}{-platform}.vsix" \
  "{url from A or B}"
```
- Always use `-L` (redirects are normal).
- Name the file `{publisher}.{extension}-{version}.vsix` (add the platform
  suffix when a `targetPlatform` was used) so multiple versions/platforms
  don't collide.
- Verify success: HTTP 200 and the file starts with `PK` (it's a zip):
  `file <downloaded>.vsix` should report "Microsoft OOXML" or "Zip archive".
  On 404, retry without `targetPlatform` (universal build) or with form B.

## Step 3 — Report

Do not run the script. Instead, hand it to the user with:
- script path (`./.cache/vscode-extensions-download/download_vscode_extensions.py`)
  and config file path
- how to run: `python ./.cache/vscode-extensions-download/download_vscode_extensions.py`
  (and CLI override options)
- note that already-downloaded extensions are skipped automatically
- install hint: `code --install-extension <path>.vsix` (or GUI:
  Extensions panel → "…" → "Install from VSIX…")

## Optional: Vim Esc keybindings template

If the default set includes `vscodevim.vim`, give the user the bundled template
`templates/vim-esc-keybindings.settings.jsonc` (relative to this skill's
directory). It maps `jj`, `kk`, `jk`, `kj` to `<Esc>` in insert mode.

Usage:
1. Show/copy the template contents to the user.
2. Target file is the user settings file for the target OS:
   - Windows: `%APPDATA%\Code\User\settings.json`
   - macOS: `~/Library/Application Support/Code/User/settings.json`
   - Linux: `~/.config/Code/User/settings.json`
   (VS Code → F1 → "Preferences: Open User Settings (JSON)").
3. If `vim.insertModeKeyBindings` already exists there, merge the four
   entries into the existing array instead of replacing it.
4. Restart VS Code (or "Developer: Reload Window") for changes to take effect.

## Example

User says "下载 C++ 插件，VS Code 1.138.0，linux-x64" — no explicit extension
list, so use the default Microsoft C/C++ set. Copy the templates, update the
copied config with the user-specified values, and hand the script to the user
(do NOT run it):

```bash
mkdir -p ./.cache/vscode-extensions-download
cp <skill-dir>/templates/download_vscode_extensions.py ./.cache/vscode-extensions-download/
cp <skill-dir>/templates/default-extensions.json ./.cache/vscode-extensions-download/
# then edit ./.cache/vscode-extensions-download/default-extensions.json:
#   "vscodeVersion": "1.138.0", "targetPlatform": "linux-x64"
```

Tell the user to run:
```bash
python ./.cache/vscode-extensions-download/download_vscode_extensions.py
```
