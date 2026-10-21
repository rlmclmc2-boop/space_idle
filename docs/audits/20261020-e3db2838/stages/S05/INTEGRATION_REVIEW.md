# S05 集成双审与分支清理记录

## 审查对象

- 获批运行与当前远端/本地 main：`5a4d52957f68b22ef47e0ad91cbe787292872d83`；运行树 `2f161d9aac91d8d615770d9480d7dd6d9247b00d`。
- 冻结集成收据：`9d55ce884fdadcf6bc0d2d75a2293776af5c13ed`，路径 `stages/S05/LOCAL_INTEGRATION.json`，Git blob `a639472ee57381c986435e96f5614249c701b9f9`。
- 阶段运行双审所据冻结证据：`375ae2f5198739b42498dcc352e0c0a5ef37ce3b`。集成双审不替换前述运行双审对象。

## 集成审查

**父级：PASS，未解决项 0。** 父级对上述运行与集成收据进行独立回读，核对结构化收据、两个构建文件 Git blob、main/受管镜像 SHA、捆绑与镜像 DLL、合成存档及本地修改保护记录。父级没有逐行审 Windows 原始日志；其结论只覆盖收据摘要及错误计数所证明的实际 `D:\放置\玩游戏.cmd` 隔离启动/重开。

**原 astra：PASS，未解决项 0。** 原线程 turn `01a15c65-f6cd-778e-83a4-6d22e76c3a2e` 对同一运行 `5a4d52957f68b22ef47e0ad91cbe787292872d83` 和同一集成收据 `9d55ce884fdadcf6bc0d2d75a2293776af5c13ed` 明确通过。没有将本地入口结果扩大为完整 Windows 发布导出结果。

集成验证：远端与 `D:\放置` main、受管镜像同 SHA；两次实际入口退出 0；15 项 JSON、26 个逐项资源和 3 个目录的构建清单，以及构建脚本与获批运行 blob 一致；镜像 DLL 与已验收捆绑 DLL 相同，D 源工作树中不同的本地 DLL 原样保留；合成存档、本地 `project.godot` 与 164 项已有跟踪修改保持原样。完整发布导出仍因先前 Windows 根证书库环境错误未获验收，保留 S22。

## 候选分支只读核查与清理阻塞

GitHub 双向 compare：`main` 对 `s05/player-release-deps` 和反向均为 `identical`，`ahead_by=0`、`behind_by=0`、merge base `5a4d52957f68b22ef47e0ad91cbe787292872d83`。该候选分支无独有提交。

初次分支删除请求被自动审批拒绝，理由是 AGENTS.md 未将分支删除列入自动授权范围；该次操作没有执行。父级随后取得用户于 **2026-10-21 03:02:09 UTC** 对**仅删除 `s05/player-release-deps`** 的明确批准。删除前再次以 GitHub compare 核对该分支与 main `identical`，`ahead_by=0`、`behind_by=0`、merge base 为 `5a4d52957f68b22ef47e0ad91cbe787292872d83`。

执行 `git -c safe.directory='D:/放置' -C 'D:\放置' push origin --delete s05/player-release-deps`，exit 0，Git 输出 `[deleted] s05/player-release-deps`。GitHub 分支搜索回读空列表，以该分支为 ref 读取 `space-battleship/tools/player_required_data.json` 返回 404 `No commit found for the ref`。**仅此 S05 临时远端分支已删除**，无独有提交或未合入运行成果；审计分支和 main 均保留。S05 阶段与线程仍由父级后续关闭，本线程不启动 S06。
