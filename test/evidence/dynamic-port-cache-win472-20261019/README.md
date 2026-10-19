# 动态炮口缓存：Windows4.7.2交付

已删除稳定段重复投影和整行数组重建。缓存使用完整依赖值快照，检测原地修改；只在缓存失效时重建投影，不修改已出生弹体快照。

## 提交与整合

- 基线：`6e8d2ed992f4239219a1348a7929ee04c59abf6a`。
- 缓存修复：`90b4c02862ad21a6e5d15ad3a9522b02395e30d2`，仅两份运行脚本和直接专项测试，123增/25删。
- main整合准备：`712d03b1375b98d0670c2e785d4886b0ec6390eb`，父提交为缓存修复和`4037308802924ffaefcb2a362028d7c91a9d4eda`。无冲突；main删除的807个路径全部保持删除，0复活。
- 整合后运行源码、资产、原生输入及专项测试与已测缓存提交完全一致。整合只承接main媒体清理，无额外游戏测试必要。没有合入或更新main，交父线程审。

## 缓存依赖与语义

`logical_fleet_pose.gd`按槽缓存完整值键：根Transform3D、挂点链、炮台pivot及pivot链、carrier归属、视口size、相机transform和Projection、武器visual_scale/anchor/pixels_per_model/emission_pixels。批准船体还包含opaque/mesh/base fit、显示高度/位置、model_span、选中硬点pos及weapon_scale。嵌套数组只在失效时深拷贝，不保留可变键别名；不依赖有遗漏的revision标记或近似浮点hash。prepare/ownership显式失效清理缓存。

显示投影用纯mount计算，不强制失效或修改独立数值muzzle缓存。缓存更新创建新PackedVector2Array，替换值而不修改先前返回数组；原生出生快照接口未改。`native_execution_session.gd`复用端口行，只检查普通友方槽；配置边界仍清理行并重新发布，敌方/无人机保持空行回退。

## 最小正确性

- 正式Godot4.7.2 / 配套Windows DLL：5717检查、0失败；四武器族×compact/noncompact各300步数值/RNG/伤害不变。
- 675个纯数据投影点与实际视觉Node3D比较，最大误差0.00006824px（门槛0.05px），覆盖5船体、4武器族、3尺度与转向。
- 64次不变查询不重复构建；26次构建路径覆盖转向、硬点原地改动、武器/船体scale、anchor、像素比例、嵌套发射像素与数量、挂点/pivot链、船体/carrier transform、fit各输入、相机/投影/视口、配置与ownership失效。
- 保留既有出生前首次显示、显示后及已退休反馈冻结检查；新增缓存返回值与已出生origin不被后续更新修改。
- 专项原来的Linux硬编码hash路径已改为按平台选DLL/SO，并显式要求64位SHA256，避免Windows空hash假通过。

## 真实高负载工作量

以下独立QA只在采样期RAM计数，未移除工作或改输出，不作为正式帧率对照。两套各精确240/480步，事件及门槛通过。

| Case | 端口查询 | 实际投影构建 | 命中率 | 端口行重建 |
|---|---:|---:|---:|---:|
| laser | 2400 | 40 | 98.33% | 8 |
| missile | 2400 | 40 | 98.33% | 8 |

旧实现每个查询都投影、每逻辑步新建整行Array；本夹具2400次投影降至40次，480次整行构建降至8次，分别减少98.33%。剩余重建来自配置/显式失效边界；值依赖检查仍按槽执行，不声称零开销。完整QA补丁及输入hash保留在counts/。

## 原驱动纯缓存前后对照

两侧固定同一份新构建DLL（SHA相同），唯一运行差异为6e8d2ed9→缓存提交的两份GDS；资产、shader、原夹具、15锁血敌人/强化40/五无人机/140级输入、自动升级、完整窗口、1×/uncapped/VSync关闭均不变。各case AB/BA各一对，8/8运行有效，全部精确240/480，事件和数值状态投影一致，四段计时非负且逐帧和正确。

| Case | 顺序 | 墙钟均值ms 前→后 | 差异 | p95ms 前→后 |
|---|---|---:|---:|---:|
| laser | AB | 6.001→5.736 | -4.41% | 9.386→9.130 |
| missile | BA | 7.304→7.353 | +0.68% | 10.152→10.174 |
| laser | BA | 5.828→5.830 | +0.03% | 9.197→9.489 |
| missile | AB | 7.271→7.146 | -1.71% | 9.984→9.829 |

整帧样本仍有波动，两组不足以宣称固定FPS收益或统计等价。验收重点是已证实的重算消除、全部失效正确性与数值/事件不变；未放宽任何采样门槛。原始完整状态hash仍仅RNG对象seed及其派生hash不同，原始失败保留，实际state及其他导出字段一致。render-wait不是物理GPU时间，本轮没有硬件GPU逐帧计量。

## Windows DLL与证据

- DLL SHA256：`137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`。原生源码未改，已用原build_native.ps1 / 固定godot-cpp507ed9d / 官方4.7.2 API / llvm-mingw clang23.1.3重编译；具体原始构建输入hash与对应Git blob见builds/manifest.json。
- [Windows DLL包](builds/windows-native.zip)：bin/space_native.dll；reference/中仅放未变化模板。沿用现有正式扩展配置，不另装第二份扩展。
- [构建及来源hash](builds/manifest.json)、build.log；[correctness.json](correctness.json)及原始日志；[analysis.json](analysis.json)、[integration-audit.json](integration-audit.json)。
- perf/保留8次原样JSON.gz/完整窗口图/日志/GetProcessTimes与NVIDIA时间线/回执；counts/保留两次独立计数与QA补丁。agenda.json固定顺序，源代码与校验脚本一并交付。
- 主分支媒体恢复仅可从历史Git读取；本交付没有把任何807个已删路径重新加入。
