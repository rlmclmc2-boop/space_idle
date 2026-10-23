# 第六段候选交接（未合 main）

唯一范围入口：[`4dc31e9:REFACTOR_NEXT.md`](https://github.com/rlmclmc2-boop/space_idle/blob/4dc31e949fae3e57f5ace659380cc3fc23869b31/space-battleship/docs/REFACTOR_NEXT.md)。代码基准和实施前远端 main 均为 `d71bd1d26d9d3a5005a891b684de531966fdab1c`；独立分支 `refactor/stage6-retire-history`。本文件及同目录证据仅供候选审查，不进入 main。

## 实施范围

- 精确退役入口指定的 980 个 Git 文件，29,016,062 字节（27.67 MiB），没有扩删。分组计数见 [deletion-summary.json](stage6-retire-history-evidence/deletion-summary.json)，完整清单由候选相对基准的删除 diff 定义。没有清理 Git 历史。
- 保留 `five-environment-20261015/baseline/` 全部 19 文件、当前 DLL/hash、共享 fixtures、所有未确认集合和未解失败证据。原始历史 JSON 清单不改写成当前状态；两处历史摘要指向固定基准提交。
- 撤销船员旧总测、缺失的 reactor 专项与 Phase9 推荐。runner 仅接受根层现存 `test_*` 单项，拒绝辅助脚本/路径参数/退役文件，超时必须为正。退出零还须识别既有完成摘要；正式入口按当前阶段识别，脚本错误和显式 FAIL 不算通过。未识别格式为 INCOMPLETE，不批量改造旧探针。
- 科研断言保留四个条件及复合结论，仅移除错误的预期整数强转，并在失败时输出子项。没有游戏代码、数值、配置、DLL 或个人存档改动。

## 科研恢复定位

原基准用现有 runner 复现 write **31/0**、reopen **30/1**。隔离副本补诊断后仍复现同一失败：selected/paid_progress/owner 为 true，input 为 false；实际 `{1:10.0,2:0.0}`（TYPE_FLOAT=3），被测试强转的预期 `{1:10,2:0}`（TYPE_INT=2）。见 [原始失败](stage6-retire-history-evidence/baseline-test-reopen.log) 与 [子项诊断](stage6-retire-history-evidence/baseline-diagnostic-reopen.log)。

`scripts/growth_number.gd:20` 将普通数归一为 float；`scripts/ai_tech_tree.gd:86` 以此安装输入。JSON 写入/读取的普通值本来就是 float。移除测试旧强转后仍按完整字典精确比较；没有放宽数值容差、跳过输入或删除断言。这里只关闭本断言的类型误比较，不推论其他历史失败。

## 本候选验证

均复用 `test/run.py` 的隔离工程和用户目录；引擎为已有 Godot 4.7.2 Windows，显式 `--godot` 指定。每个进程默认 180 秒，未运行旧探针全集。

| 现有入口 | 结果 |
|---|---|
| `test_save_boundaries.gd --headless` | write 31/0、reopen 30/0、latest 17/0、recovery 19/0 |
| `test_ordinary_entry.gd --scenario game`，非 headless | product-write 26/0、product-reopen 18/0、product-claimed-reopen 7/0；两次 `mismatches=[]` |
| `test_dynamic_native_ports.gd --headless` | 5717/0；DLL `4f19359bebcccb38d0d32ff27fc9bd887d98bef0afac5212fe440aaa1ac5b11f` |
| runner 临时核对，无新测试文件入仓 | 19/0：缺标记/零检查/失败计数/错误阶段/畸形 JSON/现有成功输出/辅助和越界入口；拒绝发生在创建隔离目录之前 |

原始 import/test 日志、JSON、四张已检查截图及 SHA256 在 [证据目录](stage6-retire-history-evidence)。日志有系统证书存储读取警告，基准和候选均存在；无脚本错误。正式入口 JSON 的 `native:false` 不扩称原生实机验收；未验证 `play_main.py` 发布启动器。其他正式场景、生命周期和挂点不作本轮重跑声明，既有第五段证据仍在其原候选。

## 保留和下一步

保留 baseline 的历史 driver 原样（其旧工作区 DLL 路径不是当前 runner 源）；compact-laser 只消费其中 fixture。保留 stage4-7-main-comparison、敌情原始未解失败、历史保存失败、native 诊断及原基准的历史审计 JSON。全部未确认集合不动。

## 双审后的三项 runner 修正

dot/high 对 `25b08f754e89b6c707ce54ff45611f6c8b19d4ba` 的审查确认删除边界、GrowthNumber 定位和上述游戏证据成立，但指出三项 runner 阻断。本轮一起修正：

1. 仅显式保留 `probe_native_admission_stale_pose.gd`，必须出现完整 `GEOMETRY LIFECYCLE` 成功摘要；前面的单条 PASS 不算完成，其他 probe 不开放。
2. `test_crew_performance.gd` 识别既有 `CREW_PERF_COMPLETE 40 scenarios`。40 来自原夹具的 2 船 × 2 页 × 3 模式 × 3 预算，加 4 个 scheduler 场景；零场景和缺场景不通过。
3. 删除 Python 任意 `passed`/`PASS:` 词命中分支，改为按现行入口匹配完整末行摘要；保留标准 unittest 及既有计数摘要。未识别旧入口为 INCOMPLETE/诊断，不继续扩兼容规则。

只补充原临时核对，合计 **33/0**，见 [runner-review-checks.json](stage6-retire-history-evidence/runner-review-checks.json)。新增核对覆盖三项回归、错误场景数、`0 passed`/`not passed`、错入口/不完整/非末行摘要、显式生命周期入口放行和其他 probe 拒绝。没有新增仓库测试文件，没有重跑游戏专项；上面的原始游戏结果只作为未改游戏代码的既有证据，不宣称本次重跑。

旧 high 已因上下文压缩停止。修正提交定位见唯一入口 `docs/REFACTOR_NEXT.md`，需由 dot 和接替 high 对同一最终候选复审；尚未获得双审 PASS，不合 main。
