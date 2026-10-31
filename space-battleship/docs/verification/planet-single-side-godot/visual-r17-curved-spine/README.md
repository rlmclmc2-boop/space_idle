# R17 星球整体结构：当前制作入口

本页只维护当前状态；下次自然交接只发本页路径和本次具体动作，不发送历史清单，不使用“末几节”。maker 当前工作不因文档整理中断。

## 当前目标与唯一批准基准

按用户已认可的[实体环带完整态 `8136cef8`](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)制作“装甲承力脊与四设施共同形体”；[闭环分步 `1eda07fd`](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)只约束独立建造累积。环须贯入设施的承力节点，不是宽托盘上摆建筑。**整体尚未通过用户／原审。**

## 当前具体动作与完成判据

**当前制作：空间站上部设备＋真实承力根壳。** 新源 `art_sources/planet_facilities_v5/build_station_node.py` 已导出；当前实机仍呈过大白顶圆盘，暗层像下挂底座，maker 正调整壳顶分段和承力层。

完成判据：在原尺寸完整态和受影响侧向角，站体体量接近批准图；环通道从低位承力口连续进入／离开，不爬前甲板；没有独立飞碟／悬挂暗盘或为遮错新增垫层。保留站顶工作部件、独立建造归属和球后深度。作者先看同版图，达到可审程度就固定候选，不自行宣布整体通过。

**提交后下一独立项：精炼上部机器与真实承力根一体制作。** 不重复只削图片暗底／改背后环宽度的失败路线；站候选送审不暂停精炼制作。

## 固定源与现场快照

快照读取于 **2026-10-31 07:13 UTC**；会变化的 WIP 以 `git status/diff` 为准，不能将本表当后续未读取的事实。

| 项目 | 当前可核事实 |
|---|---|
| 工作区／分支 | `/workspace/space_idle` · `feat/planet-single-side-ui`，不新建工作区、不合 main |
| 固定 HEAD | `662952f7c12a1f1a83412cdab4a6cefb683a7ae5`，局部候选，整体未过 |
| 站体 WIP | 新 `build_station_node.py`；修改 `auto_explore.blend`、`auto_explore.glb`、`planet_facility_scene.gd`、`planet_orbital_spine.gd`；未固定 |
| 最新同版图 | `/tmp/planet-station-load-node/stage_1.png`、`stage_3.png`、`stage_4.png`、`quarter_simulated.png`、`work_clock_4.png`；最新 07:09，尚非通过证据 |
| 可追溯运行 | `/tmp/planet-station-load-node-driver.gd`、`/tmp/planet-station-{blender,import,run}.log`；不要凭“有日志”代替看图 |
| 旧未用素材 | `refinery-orbit-supported.png`、`shipyard-docked-shuttle.png` 为旧试验，不引用／提交 |

## 原授权剩余项与依赖

1. 当前站体共同承力根及精炼完整设备／根壳；按上面的顺序继续。
2. 工坊、船坞与站／炉的主形体量和细节密度统一；环下层、自由端封装及四节点整体剪影仍未完成。已有局部记录不算销项。
3. 源码／资产版本固定后，补受改动影响的原尺寸建设态、角度和必要连续片段；旧静图、受控 90° 或旧短片不能补称新码整圈、自然施工／六类通过。不新增独立复测。
4. 资源整数接口按原 Owner 交接精确消费 `f9244a30ad1843128aaa0a620c4dc3e4866685b2`；该版仅限定只读复核通过。涉及跨 Owner 的最小文件边界须与根端协调，不拿旧 `a83` 当最终，也不阻塞主体制作。公共控件／图标由整体项目源维护，不再等待 Figma、不强制接公共壳。

保留四设施各自 built 弧段／领取业务、球环独转、探索船另轨、真实后环遮挡和前弧暗缝；保留资源身份与数值原位刷新。**只禁止三类回退：**旧整身图下面叠柱／垫片假接合；低质白盒或仅改色／环宽代替资产制作；混用旧码图、日志或数值宣称新码视觉通过。

局部提交／送审后继续下一独立项；只有真实权限／技术阻塞或明确完整版本已交用户且该项必须其决策时，才记录等待并继续其他可做项。实际压缩则保全 HEAD、WIP、最新图路径后同工作区换接替；非压缩不凭沉默换人。

<a id="problem-index"></a>
## 稳定问题索引（仅出现对应问题时读取）

| 问题 ID | 按需读取的历史，不是当前实施清单 |
|---|---|
| S1 站体／承力根 | [历史站壳与接弧](HISTORY.md#station-root) |
| S2 精炼机器／接收根 | [历史精炼圆壳](HISTORY.md#refinery-root) |
| S3 工坊共轴／球后深度 | [真实局部工坊](HISTORY.md#workshop-axis) |
| S4 船坞泊位／承力颊 | [船坞连续壳与侧窗](HISTORY.md#shipyard-berth) |
| S5 环截面／接头／端部 | [共同截面候选](HISTORY.md#spine-section) |
| S6 资源格式来源 | [已消费的公共缩写](HISTORY.md#resources)；整数 Owner 版本见上表待办 |
| S7 撤回的路线判断 | [未采用入场改动](HISTORY.md#withdrawn-route)；不是待修路线 |

完整历次证据保存在 [HISTORY.md](HISTORY.md)，原文件与原图仍可经 Git 追溯。下一次只更新本页具体动作／快照／剩余项，历史新增时按问题索引定位，不要求 maker 从头或从末尾读起。
