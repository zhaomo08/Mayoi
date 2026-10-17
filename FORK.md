# zhaomo08/Mayoi fork

自用 fork，边用边改。上游：[sorrycc/Mayoi](https://github.com/sorrycc/Mayoi)。

## 分支

- `main`：上游镜像，只做 `git merge --ff-only upstream/main`，不提交自己的改动
- `develop`：定制开发；跟进上游用 `git cherry-pick -x <sha>`

## 和上游的差异

| 改动 | 原因 |
|---|---|
| `mygo.json` 删除 `updates` | 关闭自动更新，否则会被上游 Release 覆盖掉定制 |

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

## 跟进上游

```sh
git fetch upstream
git log --oneline develop..upstream/main      # 看新提交
git checkout main && git merge --ff-only upstream/main && git push
git checkout develop && git cherry-pick -x <sha>
```

## 待办

- LSP（gopls 先行验证，再 jdtls）——暂缓，先用起来再说
