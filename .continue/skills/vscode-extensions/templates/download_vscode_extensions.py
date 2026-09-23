#!/usr/bin/env python3
"""Download VS Code extension .vsix packages from the Marketplace.

Defaults come from default-extensions.json (same directory as this script):
vscodeVersion, targetPlatform, extensions, platformSpecific.

Usage:
    python download_vscode_extensions.py                     # download the default list
    python download_vscode_extensions.py ext1 ext2 ...       # custom extension ids
    python download_vscode_extensions.py --vscode 1.85.2 --platform linux-x64 ext1 ...
    python download_vscode_extensions.py --config my.json    # custom config file
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
EXTENSIONS_FILE = os.path.join(OUTPUT_DIR, "default-extensions.json")

# Built-in fallbacks, used when the config file does not provide a value
DEFAULT_VSCODE_VERSION = "1.138.0"
DEFAULT_TARGET_PLATFORM = "win32-x64"
DEFAULT_PLATFORM_SPECIFIC = {
    "ms-vscode.cpptools",
    "ms-python.python",
    "ms-python.vscode-pylance",
    "ms-python.debugpy",
    "ms-toolsai.jupyter",
}

GALLERY_API = "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery"

# Bypass system proxy env vars (e.g. socks5://, which urllib cannot handle).
# Set VSIX_USE_PROXY=1 to keep using the system proxy instead.
if os.environ.get("VSIX_USE_PROXY") != "1":
    os.environ.pop("HTTP_PROXY", None)
    os.environ.pop("HTTPS_PROXY", None)
    os.environ.pop("ALL_PROXY", None)
    os.environ.pop("http_proxy", None)
    os.environ.pop("https_proxy", None)
    os.environ.pop("all_proxy", None)


def load_config(path: str) -> dict:
    """Load config from a JSON file, falling back to built-in defaults."""
    config = {
        "vscodeVersion": DEFAULT_VSCODE_VERSION,
        "targetPlatform": DEFAULT_TARGET_PLATFORM,
        "extensions": [],
        "platformSpecific": set(DEFAULT_PLATFORM_SPECIFIC),
    }
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        config["vscodeVersion"] = data.get("vscodeVersion", config["vscodeVersion"])
        config["targetPlatform"] = data.get("targetPlatform", config["targetPlatform"])
        config["extensions"] = data.get("extensions", config["extensions"])
        config["platformSpecific"] = set(data.get("platformSpecific", config["platformSpecific"]))
    return config


def resolve_version(ext_id: str, vscode_version: str):
    """Query the Marketplace for the latest version compatible with the target VS Code."""
    body = json.dumps({
        "filters": [{"criteria": [{"filterType": 7, "value": ext_id}]}],
        "flags": 914,
    }).encode()
    req = urllib.request.Request(
        GALLERY_API,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json;api-version=3.0-preview.1",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"  [ERROR] version query failed: {e}")
        return None
    results = data.get("results") or []
    extensions = (results[0].get("extensions") if results else None) or []
    versions = (extensions[0].get("versions") if extensions else None) or []
    if not versions:
        print("  [ERROR] extension not found on Marketplace")
        return None
    t_major, t_minor = (int(x) for x in vscode_version.split(".")[:2])

    def engine_ok(engine: str) -> bool:
        """Check an engines.vscode range against the target version.

        Handles '^x.y', '>=x.y' and plain 'x.y' minimum-version ranges.
        """
        m = re.match(r"[\^>=]*\s*(\d+)\.(\d+)(\.\d+)?", engine or "")
        if not m:
            return True  # unknown format -> assume compatible
        major, minor = int(m.group(1)), int(m.group(2))
        return (major, minor) <= (t_major, t_minor)

    for v in versions:
        for prop in v.get("properties", []):
            if prop.get("key") == "Microsoft.VisualStudio.Code.Engine":
                if not engine_ok(prop.get("value", "")):
                    break  # incompatible, try older version
        else:
            return v["version"]
    print("  [WARN] no version compatible with VS Code "
          f"{vscode_version}; using latest ({versions[0]['version']}) anyway")
    return versions[0]["version"]


def find_existing(output_dir: str) -> dict:
    """Scan output_dir for already-downloaded .vsix files.

    Returns {extension_id: filename} of the highest-version file per extension.
    """
    existing = {}
    for fn in os.listdir(output_dir):
        m = re.match(r"^(.+)-(\d+\.\d+\.\d+)(-[a-z0-9-]+)?\.vsix$", fn, re.IGNORECASE)
        if not m:
            continue
        ext_id, ver = m.group(1), m.group(2)
        key = tuple(int(x) for x in ver.split("."))
        if ext_id not in existing or key > tuple(int(x) for x in existing[ext_id][1].split(".")):
            existing[ext_id] = (fn, ver)
    return {k: v[0] for k, v in existing.items()}


def human_size(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}TB"


def progress_bar(done: int, total: int, width: int = 30) -> str:
    if total <= 0:
        return f"{human_size(done)} / ?"
    filled = min(width, int(width * done / total))
    bar = "#" * filled + "-" * (width - filled)
    pct = int(100 * done / total)
    return f"[{bar}] {pct:3d}%  {human_size(done)}/{human_size(total)}"


def download(ext_id: str, version: str, platform, output_dir: str) -> bool:
    publisher, name = ext_id.split(".")
    suffix = f"-{platform}" if platform else ""
    filename = f"{ext_id}-{version}{suffix}.vsix"
    filepath = os.path.join(output_dir, filename)
    url = (
        f"https://{publisher}.gallery.vsassets.io/_apis/public/gallery/"
        f"publisher/{publisher}/extension/{name}/{version}/assetbyname/"
        f"Microsoft.VisualStudio.Services.VSIXPackage"
    )
    if platform:
        url += f"?targetPlatform={urllib.parse.quote(platform)}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "vsix-downloader"})
        # Stream to a temp file, then validate; avoids corrupted leftovers
        # if the connection drops mid-download.
        tmp_path = filepath + ".part"
        valid = False
        try:
            with urllib.request.urlopen(req, timeout=600) as resp, open(tmp_path, "wb") as f:
                total = int(resp.headers.get("Content-Length") or 0)
                done = 0
                while True:
                    chunk = resp.read(1024 * 256)
                    if not chunk:
                        break
                    f.write(chunk)
                    done += len(chunk)
                    if sys.stderr.isatty():
                        print(f"\r  {progress_bar(done, total)}", end="", file=sys.stderr, flush=True)
            if sys.stderr.isatty():
                print(file=sys.stderr)  # newline after progress bar
            # A .vsix is a zip: must start with 'PK'
            with open(tmp_path, "rb") as f:
                valid = f.read(2) == b"PK"
        finally:
            if valid:
                os.replace(tmp_path, filepath)
                print(f"  [OK] {filename}")
            else:
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)
                if not valid:
                    print(f"  [ERROR] {ext_id}: downloaded file is not a valid vsix")
        return valid
    except urllib.error.HTTPError as e:
        if e.code == 404 and platform:
            return download(ext_id, version, None, output_dir)  # retry universal build
        print(f"  [ERROR] HTTP {e.code} for {ext_id} {version}")
        return False
    except Exception as e:
        print(f"  [ERROR] {ext_id}: {e}")
        return False


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Download VS Code extension .vsix packages")
    parser.add_argument("extensions", nargs="*", help="extension ids (default: from config file)")
    parser.add_argument("--vscode", default=None, help="target VS Code version (default: from config)")
    parser.add_argument("--platform", default=None, help="targetPlatform, e.g. win32-x64 (default: from config)")
    parser.add_argument("--config", default=EXTENSIONS_FILE, help="path to the JSON config file")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    config = load_config(args.config)

    vscode_version = args.vscode or config["vscodeVersion"]
    target_platform = args.platform or config["targetPlatform"]
    ext_ids = args.extensions or config["extensions"]
    platform_specific = config["platformSpecific"]

    if not ext_ids:
        print("No extensions specified (pass ids or set 'extensions' in the config).")
        return 1

    existing = find_existing(OUTPUT_DIR)
    if existing:
        print(f"Found {len(existing)} already-downloaded extension(s) in {OUTPUT_DIR}")

    ok = fail = skipped = 0
    for ext_id in ext_ids:
        print(f"==> {ext_id}")
        if ext_id in existing:
            print(f"  [SKIP] already downloaded: {existing[ext_id]} "
                  f"(delete it to re-download; note: platform is not checked, "
                  f"remove the file if you changed --platform)")
            skipped += 1
            continue
        version = resolve_version(ext_id, vscode_version)
        if not version:
            print("  [ERROR] could not resolve version")
            fail += 1
            continue
        print(f"  version: {version} (target VS Code {vscode_version})")
        platform = target_platform if ext_id in platform_specific else None
        if download(ext_id, version, platform, OUTPUT_DIR):
            ok += 1
        else:
            fail += 1
    print(f"\nDone: {ok} downloaded, {skipped} skipped, {fail} failed -> {OUTPUT_DIR}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
