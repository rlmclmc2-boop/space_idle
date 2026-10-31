# R17 星球整体结构：当前制作入口

本页为`a40cbae1`最新文档快照（源码仍为`662952f7`），跨组整理未读取maker未提交现场。原协调[分支入口](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md)保持独立更新。

本页只维护当前状态；下次自然交接只发本页路径和本次具体动作，不发送历史清单，不使用“末几节”。maker 当前工作不因文档整理中断。

## 当前目标与唯一批准基准

按用户已认可的[实体环带完整态 `8136cef8`](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)制作“装甲承力脊与四设施共同形体”；[闭环分步 `1eda07fd`](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)只约束独立建造累积。环须贯入设施的承力节点，不是宽托盘上摆建筑。**整体尚未通过用户／原审。**

## 当前具体动作与完成判据

**当前制作：重新构思站／炉的完整承力建筑资产。** 空间站用 Blender 贯通压力壳与 ImageGen 透明上部在原尺寸实机试装：全模型成为浅圆盘，上部加根壳则成浅盘摆小塔，均低于原站图。精炼厂又试了真实单壳压力框与配准插画、全真 3D 炉与双料斗、以及 ImageGen 四材质图集映射全真模型；在同一原尺寸画面分别成浅色方壳垫在炉下、白色简模、表面改善但仍是小玩具且前弧根部不读承力。全部从正式运行源撤回，不作可审候选。失败源码／补丁分别在 `/tmp/planet-build-station-node-rejected.py`、`/tmp/planet-build-refinery-{node,integral,painted}-rejected.py` 与相邻 `*-rejected.patch`，同码图在 `/tmp/planet-station-load-node/`、`/tmp/planet-refinery-pressure-node/`、`/tmp/planet-refinery-integral/`。继续制作必须改变整体形体与材质映射，不重复“图叠壳”或无细节白模。

完成判据：原尺寸完整态及受影响侧向角下，站／炉的环通道从低位承力口连续进入和离开，四节点材质、体量和细节密度共同成形；炉的双料斗、接收口及工作动作、站顶运动部件仍可读；无飞碟、暗盘、浅方壳、外挂三件或假垫层。保留各自独立建造归属和球后深度。达到可审程度才固定候选，不自行宣布整体通过。

**下一独立项：环下暗层与自由端整段封装。** 站／炉完整资产仍是主任务；两项能独立制作，均不以局部替代整体审。

## 固定源与现场快照

快照读取于 **2026-10-31 07:31 UTC**；会变化的 WIP 以 `git status/diff` 为准，不能将本表当后续未读取的事实。

| 项目 | 当前可核事实 |
|---|---|
| 工作区／分支 | `/workspace/space_idle` · `feat/planet-single-side-ui`，不新建工作区、不合 main |
| 起点 HEAD | `e7ff7673eea06611ca65337c58f32e248115cc13`，文档分离后的局部候选，整体未过；本页提交后以新 HEAD 为准 |
| 站／炉 WIP | 均已撤回，原运行资产／脚本保留；下一轮须换形体制作路线 |
| 最近退回实屏 | `/tmp/planet-station-load-node/`、`/tmp/planet-refinery-pressure-node/`、`/tmp/planet-refinery-integral/`；是失败试装，不是当前码验收图 |
| 可追溯运行 | `/tmp/planet-station-load-node-driver.gd`、`/tmp/planet-refinery-{pressure-node,integral}-driver.gd` 及同前缀日志；不要混用新旧版本图 |
| 旧未用素材 | `refinery-orbit-supported.png`、`shipyard-docked-shuttle.png` 为旧试验，不引用／提交 |

## 原授权剩余项与依赖

1. 精炼完整设备／根壳与站体共同承力节点均独立未完；按上文完成判据继续新形体制作。
2. 工坊、船坞与站／炉的主形体量和细节密度统一；环下层、自由端封装及四节点整体剪影仍未完成。已有局部记录不算销项。
3. 源码／资产版本固定后，补受改动影响的原尺寸建设态、角度和必要连续片段；旧静图、受控 90° 或旧短片不能补称新码整圈、自然施工／六类通过。不新增独立复测。
4. 资源整数接口按原 Owner 交接精确消费 `f9244a30ad1843128aaa0a620c4dc3e4866685b2`；该版仅限定只读复核通过。星球余额现已原位读 Economy `balance_rows()`，新版 Owner 的整数文本可沿这一出口消费，无本模块另造格式器或费用行。直接将 `aaba..f924` Owner 补丁套到本分支会在 Session、Economy、Reactor 与已有前置功能冲突；一次试合已撤回，未留下半套逻辑，需按最新 Owner 语义及本分支前置逐方法整合。不拿旧 `a83` 当最终，也不阻塞主体制作。公共控件／图标由整体项目源维护，不再等待 Figma、不强制接公共壳。

保留四设施各自 built 弧段／领取业务、球环独转、探索船另轨、真实后环遮挡和前弧暗缝；保留资源身份与数值原位刷新。**只禁止三类回退：**旧整身图下面叠柱／垫片假接合；低质白盒或仅改色／环宽代替资产制作；混用旧码图、日志或数值宣称新码视觉通过。

局部提交／送审后继续下一独立项；只有真实权限／技术阻塞或明确完整版本已交用户且该项必须其决策时，才记录等待并继续其他可做项。实际压缩则保全 HEAD、WIP、最新图路径后同工作区换接替；非压缩不凭沉默换人。

<a id="problem-index"></a>
## 稳定问题索引（仅出现对应问题时读取）

| 问题 ID | 按需读取的历史，不是当前实施清单 |
|---|---|
| S1 站体／承力根 | [历史站壳与接弧](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#station-root) |
| S2 精炼机器／接收根 | [历史精炼圆壳](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#refinery-root) |
| S3 工坊共轴／球后深度 | [真实局部工坊](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#workshop-axis) |
| S4 船坞泊位／承力颊 | [船坞连续壳与侧窗](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#shipyard-berth) |
| S5 环截面／接头／端部 | [共同截面候选](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#spine-section) |
| S6 资源格式来源 | [已消费的公共缩写](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#resources)；整数 Owner 版本见上表待办 |
| S7 撤回的路线判断 | [未采用入场改动](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md#withdrawn-route)；不是待修路线 |

完整历次证据保存在 [HISTORY.md](https://github.com/rlmclmc2-boop/space_idle/blob/a40cbae14204f68254f46e0b2a69bb51ac5d00aa/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HISTORY.md)，原文件与原图仍可经 Git 追溯。下一次只更新本页具体动作／快照／剩余项，历史新增时按问题索引定位，不要求 maker 从头或从末尾读起。
