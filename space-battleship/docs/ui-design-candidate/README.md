# 桌面前端结构修订02

**待独立审核与父审，未接入游戏，未批准美术。** 修订01 `ef74a539`已因结构问题未通过；本轮集中修正三个代表舱室。用户已取消本阶段窄屏布局、适配与专项检查，未来恢复须另行明确。本轮只看桌面宽屏。

正式唯一入口仍为[game-design/README.md](../game-design/README.md)，范围修正已独立提交`8a74eadb`（只改README与13，可单独挑取）。其余设计、代码和截图均在本目录；不改后端/Excel/共用契约，不合main。

代码阅读快照260b593；共用业务接口仍引用[`a4d947fd:interface-candidate.md`](https://github.com/rlmclmc2-boop/space_idle/blob/a4d947fd504ae75efb5a1ae6359f3d01a20cedbf/interface-candidate.md)，不是已实现的新协议。后续说明：伤害receipt由BattleView单一消费；五舰无人机容量已定1/2/3/4/5，前端读公开输出。其余版本与裁定由父线程提供。

## 先看整屏

[preview.html](preview.html)使用本目录的desktop.css/desktop.js和仓库现有资产。从`space-battleship/`启动`python -m http.server 8765`，浏览`http://127.0.0.1:8765/docs/ui-design-candidate/preview.html`。无构建、无联网依赖。底部“审阅场景”切固定样例状态，不是产品控件；本稿没有真实业务操作。

| 代表画面 | 证据 |
|---|---|
| 反应炉：连续供能安装平面 | [1440整屏](evidence/reactor-1440x960.png)、[1200桌面压力样本](evidence/reactor-1200x900.png) |
| 反应炉：单设备错误就地显示 | [非法草稿](evidence/reactor-invalid-1440x960.png) |
| 科研：整舱场景，投入终端按需展开 | [常态](evidence/research-1440x960.png)、[展开终端](evidence/research-terminal-1440x960.png) |
| 科研：工作量/效果/状态 | [暂停](evidence/research-paused-1440x960.png)、[完成](evidence/research-complete-1440x960.png)、[选择](evidence/research-choice-1440x960.png) |
| 舰装：挂点选槽→比较→费用/冷却→回执 | [比较](evidence/equipment-1440x960.png)、[冷却](evidence/equipment-cooldown-1440x960.png)、[费用不足](evidence/equipment-insufficient-1440x960.png)、[成功](evidence/equipment-success-1440x960.png) |

## 本轮变更与审阅身份

- **用户已定范围：** 桌面宽屏持续战场与模块并列；本轮窄屏工作排除。设备图、比值、断点、框架比例仍是候选。
- **反应炉修订：** 核心与三种独立设备在同一供能平面，不再是巨大核心旁的微型图框；主管从核心出口分支到设备入口。清零/草稿/错误/实际值各归单设备，统一控制只留均分/核心购级。图为结构占位，不是新设备定稿。
- **科研修订：** 工厂占据舱室主体，默认无常驻大投入表单；右下终端按需展开，避让中部机器。补当前生效效果、下一等级、工作量、暂停/完成与选择状态。
- **舰装修订：** 选船体武器挂点与逻辑防御槽，同步右侧同一槽位比较台。补费用、换装冷却、拒绝和成功代表状态；候选选择不改变当前装配。
- **审美待审：** 奶油白/海军蓝/青色等是历史规范及资产来源。本稿配色比例、材质表达和整体审美尚未获批，不能冻结为用户已批准的新审美。
- **尚未完成：** 其他模块视觉细稿、完整换舰/批量装备事务、真实资产安装元数据、舰体/炮台动态净空、游戏接入和V0–V10实机验收。

本稿全部金额、效果、费用、等级与回执为固定排版样例，不证明真实配置组合、解锁或计算正确。未生成最终资产。历史窄屏截图已退出当前目录，可在ef74a539追溯；不再保留30%/42%方案供选择。

[结构说明](design.md) · [资产与来源](assets-and-sources.md) · [验证与剩余工作](validation.md)
