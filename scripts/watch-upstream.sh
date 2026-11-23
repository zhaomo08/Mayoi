#!/bin/zsh
#
# Copyright (C) 2025 saymeevetime.cn
#
# @author Chester
# @date 2026-11-23
# @description Mayoi 上游更新定时检查与 Telegram 监控推送脚本
#

set -euo pipefail

REPO_DIR="/Users/mesay/GitHub_Project/Mayoi"
WATCH_DIR="$HOME/.mayoi/watch"
mkdir -p "$WATCH_DIR"

LAST_NOTIFIED_FILE="$WATCH_DIR/.last_notified_sha"
SEND_SCRIPT="$HOME/.agents/skills/xhs-ops/scripts/send.sh"
MSG_FILE="$WATCH_DIR/msg.tmp"

cd "$REPO_DIR" || exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 检查 Mayoi 上游更新..."
git fetch upstream

UPSTREAM_SHA=$(git rev-parse upstream/main)
BEHIND_COUNT=$(git rev-list --count HEAD..upstream/main)

if (( BEHIND_COUNT == 0 )); then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 本地已是最新，无新更新。"
  exit 0
fi

# 检查是否已经通知过该 commit，防止重复推送轰炸
if [[ -f "$LAST_NOTIFIED_FILE" ]] && [[ "$(cat "$LAST_NOTIFIED_FILE" 2>/dev/null)" == "$UPSTREAM_SHA" ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 发现新提交 (${BEHIND_COUNT} 个)，但该版本此前已发送过通知，跳过本次推送。"
  exit 0
fi

UPSTREAM_TAG=$(git describe --tags --abbrev=0 upstream/main 2>/dev/null || echo "upstream/main")
CURRENT_TAG=$(grep '"version":' mygo.json | head -1 | tr -dc '0-9.')
RECENT_LOGS=$(git log --oneline -n 6 develop..upstream/main)

cat <<EOF > "$MSG_FILE"
🔔 Mayoi 上游有新版本可跟进！

• 本地版本: v${CURRENT_TAG}
• 上游最新: ${UPSTREAM_TAG} (落后 ${BEHIND_COUNT} 个提交)

【最新改动摘要】
${RECENT_LOGS}

【一键更新命令】
cd ~/GitHub_Project/Mayoi && ./scripts/sync-upstream.sh --install
EOF

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 发送 Telegram 提醒..."
if [[ -x "$SEND_SCRIPT" ]]; then
  "$SEND_SCRIPT" -m "$MSG_FILE"
  echo "$UPSTREAM_SHA" > "$LAST_NOTIFIED_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 提醒推送成功。"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] 未找到可执行的 Telegram 推送脚本: $SEND_SCRIPT"
  cat "$MSG_FILE"
fi

rm -f "$MSG_FILE"
