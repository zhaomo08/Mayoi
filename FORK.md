# zhaomo08/Mayoi fork

自用 fork，边用边改。上游：[sorrycc/Mayoi](https://github.com/sorrycc/Mayoi)。

## 分支

- `main`：上游镜像，只做 `git merge --ff-only upstream/main`，不提交自己的改动
- `develop`：定制开发；跟进上游用 `git merge upstream/main`（只挑部分提交时用 `cherry-pick -x`）

## 提交去向

日常改动只提交并推送到本仓库（`origin`）。只有明确要给作者修 issue 时，才向 `sorrycc/Mayoi` 提 PR。

## 和上游的差异

| 改动 | 原因 |
|---|---|
| `mygo.json` 删除 `updates` | 关闭自动更新，否则会被上游 Release 覆盖掉定制 |
| 图标换成简单的编辑器窗口（`cmd/mayoi/icon-art.png`，再 `go run ./tools/icongen` 生成 `resources/icon.png`） | 自用偏好 |
| `scripts/sync-upstream.sh` | 一键合并上游、维持定制（自动去 updates、维持自用图标）、编译并安装脚本 |
| `scripts/watch-upstream.sh` | 上游版本定时检查、去重与 Telegram 提醒脚本（配合 LaunchAgent） |

定制尽量写成新文件（`cmd/mayoi/x_*.go`、`internal/<新包>`），上游文件只留挂载点，降低 cherry-pick 冲突。
自己的改动不写进 `CHANGELOG.md`（上游文件，必冲突），记在上表。

## 构建与安装

本机 Xcode 许可未同意，用 Command Line Tools 编译即可：

```sh
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
go tool mygo build                                   # → build/darwin-arm64/Mayoi.app
ditto build/darwin-arm64/Mayoi.app /Applications/Mayoi.app
```

安装前先退出正在运行的 Mayoi。`mayoi` 命令：菜单 **File → Install 'mayoi' Command**。

## 跟进上游与自动化更新

### 自动化监控 (LaunchAgent)
本机已配置后台定时监控任务（`com.mesay.mayoi-watch`），每天 10:30 自动检查上游新提交/Release。有新更新时自动通过 Telegram 推送通知与一键更新指令。

### 一键更新脚本
收到通知或想手动更新时：
```sh
./scripts/sync-upstream.sh --install   # 自动合并上游、维持自用定制、编译并替换安装
./scripts/sync-upstream.sh --check-only # 仅查看上游是否有新变动
```

也可以按传统方式手动操作：
```sh
git fetch upstream
git log --oneline develop..upstream/main      # 看新提交
git checkout main && git merge --ff-only upstream/main && git push
git checkout develop && git merge upstream/main   # 冲突时我们已合入上游的改动取 --theirs
```

## 当前版本

- 2026-11-23：建立定时检查（LaunchAgent: `com.mesay.mayoi-watch`）与一键更新脚本（`scripts/sync-upstream.sh`）；跟进上游 `v0.23.2`。
- 2026-11-10：已跟进上游 `v0.19.2`（插件系统、`mayoi settings`），保留自定义图标和关闭自动更新设置。
- 本机安装由此仓库构建；更新时合并上游、执行针对性测试，再构建安装。

## 待办

- LSP（gopls 先行验证，再 jdtls）——暂缓，先用起来再说

## 已合入上游的贡献

- [PR #45](https://github.com/sorrycc/Mayoi/pull/45)：修复 diff 向右拆分闪退（#20/#39），v0.11.0 起包含
- [PR #49](https://github.com/sorrycc/Mayoi/pull/49)：Source Control 列出子目录里的独立仓库（#17），已随 v0.16.2 合并跟进
