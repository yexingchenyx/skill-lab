#!/usr/bin/env bash
# create-cpp-project.sh — 用 Continue CLI 调用 create-cpp-project skill，
# 在 .cache 目录下创建工程 cpp_pj，并编译、运行测试验证
# 用法: ./create-cpp-project.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$SCRIPT_DIR/.cache/cpp_pj"

mkdir -p "$SCRIPT_DIR/.cache"
cd "$SCRIPT_DIR/.cache"

# 非交互模式调用 Continue CLI（--auto 允许其执行所需工具），
# 创建工程并编译、跑测试验证
cn -p --auto \
  "使用 create-cpp-project skill 在当前目录创建名为 cpp_pj 的 C++ 工程（C++20，包含 Google Test）。创建完成后编译工程并运行全部测试，确保构建和测试全部通过。" \
  2>&1

echo
echo "=== 工程目录: $TARGET_DIR ==="
if [[ -d "$TARGET_DIR" ]]; then
    ls "$TARGET_DIR"
else
    echo "（未生成，请检查上方 CLI 输出）" >&2
    exit 1
fi
