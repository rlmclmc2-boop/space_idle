# 桌面前端修订03：六项复审修正

**待独立审核与父审，未接入游戏，未批准美术。** 结构02 `f806a0d4`方向保留但未通过；本轮按[独立报告10733223](https://github.com/rlmclmc2-boop/space_idle/blob/10733223b1ce801781cfba18afeaba547b4484bf/space-battleship/docs/review-evidence/frontend-revision02-f806-independent.md)修正UI-01–UI-06，保留已经成立的场景关系。用户已取消本阶段窄屏布局、适配与专项检查，未来恢复须另行明确。本轮只看桌面宽屏。

正式唯一入口为[main@08bf2e1e的game-design/README.md](https://github.com/rlmclmc2-boop/space_idle/blob/08bf2e1e10d69a5edf2e94919ffc9357234129d9/space-battleship/docs/game-design/README.md)，范围修正已独立挑取为93d64f30与08bf2e1e。其余设计、代码和截图均在本目录；不改后端/Excel/共用契约，不合main。

代码阅读快照260b593；共用业务接口仍引用[`a4d947fd:interface-candidate.md`](https://github.com/rlmclmc2-boop/space_idle/blob/a4d947fd504ae75efb5a1ae6359f3d01a20cedbf/interface-candidate.md)，不是已实现的新协议。后续说明：伤害receipt由BattleView单一消费；五舰无人机容量已定1/2/3/4/5，前端读公开输出。其余版本与裁定由父线程提供。

## 先看整屏

[preview.html](preview.html)使用本目录的desktop.css/desktop.js和仓库现有资产。从`space-battleship/`启动`python -m http.server 8765`，浏览`http://127.0.0.1:8765/docs/ui-design-candidate/preview.html`。无构建、无联网依赖。底部“审阅场景”切固定样例状态，不是产品控件；本稿没有真实业务操作；“应用”仅切固定演示数据，不证明业务接入。

| 代表画面 | 证据 |
|---|---|
| 反应炉：连续供能安装平面 | [1440整屏](evidence/reactor-1440x960.png)、[1200桌面压力样本](evidence/reactor-1200x900.png) |
| 反应炉：单设备错误就地显示 | [非法草稿](evidence/reactor-invalid-1440x960.png) |
| 科研：整舱场景，投入终端按需展开 | [常态](evidence/research-1440x960.png)、[展开终端](evidence/research-terminal-1440x960.png) |
| 科研：工作量/效果/状态 | [暂停](evidence/research-paused-1440x960.png)、[完成](evidence/research-complete-1440x960.png)、[选择](evidence/research-choice-1440x960.png) |
| 舰装：挂点选槽→比较→费用/冷却→回执 | [比较](evidence/equipment-1440x960.png)、[冷却](evidence/equipment-cooldown-1440x960.png)、[费用不足](evidence/equipment-insufficient-1440x960.png)、[成功](evidence/equipment-success-1440x960.png) |

## 六项复审修正及证据

| 报告项 | 本轮修正 | 状态截图 |
|---|---|---|
| UI-01 候选决策信息 | 一体化当前/下级效果、18K/100K保留工作量、预计余时，以及原研究62K保留均直接排出 | [候选](evidence/research-choice-1440x960.png) |
| UI-02 自动投入 | 增加开关/共同预算比例草稿、当前设置、应用/还原及60游戏秒刷新时机；应用设置不立即改变实际铁铀投入；岗位续研独立 | [未应用](evidence/research-automatic-1440x960.png)、[已应用设置](evidence/research-automatic-applied-1440x960.png) |
| UI-03 完成与下一次预览 | 成功后撤回旧候选、费用与提交按钮；新当前值单列，旧操作仅在已完成回执中查阅，下一次预览尚未生成 | [成功](evidence/equipment-success-1440x960.png)、[回执展开](evidence/equipment-receipt-1440x960.png) |
| UI-04 选择层遮挡 | 选择层移右，当前身份留左，进度条完整放在左下；当前机器与探针均避让 | [1440](evidence/research-choice-1440x960.png)、[1200](evidence/research-choice-1200x900.png) |
| UI-05 单资源提交 | 铁/铀各有当前值、草稿、应用/还原与独立结果；展示铁成功而铀失败，不暗示双资源原子事务 | [逐资源投入](evidence/research-terminal-1440x960.png)、[分别回执](evidence/research-partial-1440x960.png) |
| UI-06 反馈语义 | 中性圆点、成功勾、错误方框叹号及不同底色/边框；成功通知4.5秒后收回，已完成记录仍可查 | [中性](evidence/equipment-1440x960.png)、[错误](evidence/equipment-insufficient-1440x960.png)、[通知收回后](evidence/equipment-settled-1440x960.png) |

以上为候选修正，不自判独立审核通过。当前目录共19张桌面整屏，原结构02可在f806a0d4追溯。

## 保留的结构与审阅身份

- **用户已定范围：** 桌面宽屏持续战场与模块并列；本轮窄屏工作排除。设备图、比值、断点、框架比例仍是候选。
- **反应炉修订：** 核心与三种独立设备在同一供能平面，不再是巨大核心旁的微型图框；主管从核心出口分支到设备入口。清零/草稿/错误/实际值各归单设备，统一控制只留均分/核心购级。图为结构占位，不是新设备定稿。
- **科研修订：** 工厂占据舱室主体，默认无常驻大投入表单；右下终端按需展开，避让中部机器。补当前生效效果、下一等级、工作量、暂停/完成与选择状态。
- **舰装修订：** 选船体武器挂点与逻辑防御槽，同步右侧同一槽位比较台。补费用、换装冷却、拒绝和成功代表状态；候选选择不改变当前装配。
- **审美待审：** 奶油白/海军蓝/青色等是历史规范及资产来源。本稿配色比例、材质表达和整体审美尚未获批，不能冻结为用户已批准的新审美。
- **尚未完成：** 其他模块视觉细稿、完整换舰/批量装备事务、真实资产安装元数据、舰体/炮台动态净空、游戏接入和V0–V10实机验收。

本稿全部金额、效果、费用、等级与回执为固定排版样例，不证明真实配置组合、解锁或计算正确。未生成最终资产。历史窄屏截图已退出当前目录，可在ef74a539追溯；不再保留30%/42%方案供选择。

[结构说明](design.md) · [资产与来源](assets-and-sources.md) · [验证与剩余工作](validation.md)
