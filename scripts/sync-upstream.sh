#!/bin/bash
#
# Copyright (C) 2025 saymeevetime.cn
#
# @author Chester
# @date 2026-11-23
# @description Mayoi 上游同步、定制保护与一键编译安装脚本
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

INSTALL=false
FORCE=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install|-i|-y|--yes)
      INSTALL=true
      shift
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --check-only|-c)
      CHECK_ONLY=true
      shift
      ;;
    -h|--help)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  --install, -i, -y   合并上游并自动构建安装到 /Applications/Mayoi.app"
      echo "  --force, -f         无视上游是否有新提交，强制重新编译安装"
      echo "  --check-only, -c    仅检查上游是否有新版本，不执行合并和构建"
      exit 0
      ;;
    *)
      echo "未知选项: $1" >&2
      exit 1
      ;;
  esac
done

echo "==> 检查本地 Git 状态..."
if [[ -n $(git status --porcelain) ]]; then
  echo "错误: 本地工作区有未提交的改动，请先保存或暂存后再执行同步。" >&2
  exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT_BRANCH" != "develop" ]]; then
  echo "提示: 当前分支为 $CURRENT_BRANCH，切换到 develop 分支..."
  git checkout develop
fi

echo "==> 正在抓取上游更新 (upstream)..."
git fetch upstream

BEHIND_COUNT=$(git rev-list --count HEAD..upstream/main)
UPSTREAM_TAG=$(git describe --tags --abbrev=0 upstream/main 2>/dev/null || echo "upstream/main")
CURRENT_TAG=$(git describe --tags --abbrev=0 develop 2>/dev/null || grep '"version":' mygo.json | head -1 | tr -dc '0-9.')

echo "本地当前版本: v${CURRENT_TAG}"
echo "上游最新版本: ${UPSTREAM_TAG} (落后 ${BEHIND_COUNT} 个提交)"

if [[ "$CHECK_ONLY" == true ]]; then
  if (( BEHIND_COUNT > 0 )); then
    echo "发现新提交:"
    git log --oneline -n 10 develop..upstream/main
  else
    echo "本地已是最新，无待同步提交。"
  fi
  exit 0
fi

if (( BEHIND_COUNT == 0 )) && [[ "$FORCE" == false ]]; then
  echo "==> 本地代码已与上游 main 保持最新，无需更新。"
  if [[ "$INSTALL" == true ]]; then
    echo "若需要强制重新构建并覆盖安装，请添加 --force 参数。"
  fi
  exit 0
fi

if (( BEHIND_COUNT > 0 )); then
  echo "==> 正在合并上游更新 (upstream/main)..."
  git merge upstream/main -m "Merge upstream ${UPSTREAM_TAG} into develop"
fi

echo "==> 检查并维持自用定制配置..."
# 1. 确保关闭后台自动更新 (删除 mygo.json 中的 updates 配置)
if grep -q '"updates":' mygo.json 2>/dev/null; then
  echo "检测到 mygo.json 包含 updates 配置，自动移除以防止自用定制被官方 Release 覆盖..."
  node -e '
    const fs = require("fs");
    const p = "mygo.json";
    const j = JSON.parse(fs.readFileSync(p, "utf8"));
    if (j.updates) {
      delete j.updates;
      fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
    }
  '
  git add mygo.json
  git commit -m "Disable auto-update for customized fork" || true
fi

# 2. 确保自用定制图标有效
if [[ -f cmd/mayoi/icon-art.png ]]; then
  echo "确保自用应用图标已正确生成..."
  go run ./tools/icongen
  if [[ -n $(git status --porcelain resources/icon.png) ]]; then
    git add resources/icon.png
    git commit -m "Regenerate custom app icon" || true
  fi
fi

# 3. 顺便快进同步 main 分支（如果可以）
if git show-ref --verify --quiet refs/heads/main; then
  echo "==> 快进同步本地 main 分支镜像..."
  git checkout main
  git merge --ff-only upstream/main || true
  git checkout develop
fi

echo "==> 开始编译构建 Mayoi.app..."
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
go tool mygo build

BUILD_APP="build/darwin-arm64/Mayoi.app"
if [[ ! -d "$BUILD_APP" ]]; then
  echo "错误: 编译输出未找到 $BUILD_APP" >&2
  exit 1
fi
echo "==> 编译完成: $BUILD_APP"

if [[ "$INSTALL" == false ]]; then
  read -r -p "是否现在覆盖安装到 /Applications/Mayoi.app ? [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    INSTALL=true
  fi
fi

if [[ "$INSTALL" == true ]]; then
  echo "==> 准备安装到 /Applications/Mayoi.app..."
  if pgrep -x "Mayoi" >/dev/null 2>&1; then
    echo "正在退出运行中的 Mayoi..."
    pkill -x "Mayoi" || true
    sleep 1
  fi

  if [[ -d /Applications/Mayoi.app ]]; then
    echo "备份当前 /Applications/Mayoi.app 到 /Applications/Mayoi.app.bak..."
    rm -rf /Applications/Mayoi.app.bak
    cp -R /Applications/Mayoi.app /Applications/Mayoi.app.bak
  fi

  echo "写入新版本至 /Applications/Mayoi.app..."
  ditto "$BUILD_APP" /Applications/Mayoi.app
  echo "==> 安装完成！已更新为 ${UPSTREAM_TAG}。"
  echo "启动 Mayoi 后，可通过菜单 File -> Install 'mayoi' Command 确保命令行工具保持最新。"
else
  echo "跳过安装步骤。您稍后可随时运行: ditto $BUILD_APP /Applications/Mayoi.app"
fi
