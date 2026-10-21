# S08 集成同对象双审记录

- 批准运行 SHA：`cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8`
- 集成完整证据 SHA：`801ab029fe2eb0680d4133593b35cf651b1d3cbc`（本审查记录写入前的冻结提交）
- 本地集成收据：`stages/S08/LOCAL_INTEGRATION.json`，八份原始入口、导入、游戏及启动收据日志在 `stages/S08/integration-logs/`。
- 运行审查已对 `cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8` / `088e8ba5a0fdeabd760cd879bd647f1947e2c7d0` 同对象双 PASS，记录见 `stages/S08/FINAL_REVIEW.md`。

## 父级独立集成结论

`PASS`，审查运行 `cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8` / 完整集成证据 `801ab029fe2eb0680d4133593b35cf651b1d3cbc`；未解决项为空。父级独立回读集成收据和八份原始 entry/import/game/launch 文件，重算八项 SHA-256 与 Git blob 均匹配；日志无脚本、解析或 ERROR 行，同一运行 SHA、DLL 与隔离用户路径一致。两工具编译导入及本地编辑保护与收据一致。父级此轮没有直接重跑 Windows；不把两次 120 帧入口验收宣称为存档往返。结论由父级线程 `01a159d3-1f8d-710e-9f91-496fe15aa0d8` 转达。

## 原 astra 独立集成结论

`PASS`，审查同一运行 `cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8` / 同一完整集成证据 `801ab029fe2eb0680d4133593b35cf651b1d3cbc`；未解决项为空。原 astra 回合 `01a15cdf-8dab-7363-ae28-6a856c529dd9` 核对 182 项摘要、八份集成文件、两个工具 Git blob 与 DLL 摘要匹配。

## 保护、范围与分支待办

远端 main、`D:/放置` main、`origin/main` 与 managed mirror 均为批准运行 SHA。入口首启与重开各 120 帧 exit 0，使用同一隔离验证用户目录；原有 `player-window-check` 已恢复，S08 验证目录另行保留。项目 `project.godot` 本地修改仍在，个人存档未触及。隔离目录未生成进度档，本阶段不声称保存/重载往返或完整 native 验收。

只读回查 `s08/config-recovery` 和 main 的远端 tip 都为 `cf213e2f36e4b0ec60a0629e2ed641ac93ef5cd8`，独有运行提交为 0；分支仍存在，仅登记待专项清理，不执行删除。S06/S07 分支清理待办继续保留。S08 关闭及实施线程归档由父级随后执行；本记录不自行开启 S09。
