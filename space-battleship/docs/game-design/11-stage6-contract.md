# 11 当前制作、验收边界与历史索引

[唯一入口](README.md)。本文只维护本次取回的固定快照与覆盖边界，不定义玩法/布局或授权运行测试；版本更新必须重新读对应源，不拿表格代替他人WIP现场。

## 当前固定版本（2026-10-31 UTC）

| 组 | 独立分支与固定版本 | 当前一步与覆盖边界 |
|---|---|---|
| main | `e3b38d7b6d8256f6031e1b086c7db7812b6a441f` | 仅已合入基线；不含下列所有最新制作，不是最新设计决定的总和 |
| 整体 | `design/clear-zone-host@6e0e86c80d7cc7ee4f8623fca929c2f4828b6215` | [R3入口](../ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md)：方向已认可，059ac公共运行材质已固定；仅公共设置/弹层有限状态，装备/B01待消费，未整体通过 |
| 装备 | `art/equipment-materials-main-20261029@d799954d2e9c390872e9ac548c6bc541b8050bd3` | [逐槽入口](../verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md)：22395排版证据与此后helper差异分开；R3接入/整页仍未完 |
| 反应堆 | `implement/reactor-centered-godot@73ee39c08b03ff6a4845f7d317baf4cdedc92874` | [B01入口](../verification/reactor-centered-godot/evidence/b01-redesign/README.md)：新可组合核心/设备/管路八态，最终资产连续片与可比性能未齐；旧用户退回覆盖旧视觉通过 |
| 星球 | `feat/planet-single-side-ui@a40cbae14204f68254f46e0b2a69bb51ac5d00aa`（文档）；源码`662952f7c12a1f1a83412cdab4a6cefb683a7ae5` | [R17入口](../verification/planet-single-side-godot/visual-r17-curved-spine/README.md)：原协调07:31快照：站/炉试装已撤回，换完整形体路线；下一独立项环下暗层/自由端；整数Owner试合已撤回，待逐方法整合；本整理未读其未提交现场 |
| 后台 | `feat/amount-safe-previews@ad4c01d7fd765a20701845b8bf0effe7ae217c91`（文档）；实现`f9244a30ad1843128aaa0a620c4dc3e4866685b2` | [资源契约](contracts/resources.md)：奖励校验/chrono退点获同一Astra限定只读复核；91项是作者证据，非全局实机/独立复测/main验收，消费者待精确合并 |

四制作组均未整体完成或合main。以上分支不是同一运行版；禁止把不同源码、资产、旧静图/片或局部通过拼成整版验收。R3原14:52附件、透明图标静态修订、公共运行状态三种证据分别保留。

## 当前依赖与判定

- 公共材质：6e0/059ac最小接口已交原组；原节点替换旧面层并回同版整页/状态，不强制三分支立即接公共壳，不继续等待Figma。
- 图标：R3静态截图裁片带旧底已定位；按ID用原alpha纹理。透明标准、费用两键、数字/资源显示只在[13](13-art-interaction.md)，模块交换只在[14](14-ui-contracts.md)。
- 资源：以f924必要Owner差异精确合并，不能从后台旧树覆盖新UI；公共兼容行格式或装备helper窄接不代表全局结算/显示完成。
- 不确定项见[裁定清单](review/conflicts.md)：C4身份/保存水位、首槽双零判定仍未决；D9配置身份、D10分配提交语义、D11六类设施范围保留双方来源等待裁定。无争议制作继续。
- 证据判断按[07](07-verification.md)与[13§6](13-art-interaction.md#6-制作与双审证据口径)，整页视觉不能以清单清零、API存在或文档整理替代。旧阶段测试禁令/提案不变成本任务命令；本次只核文档。

## 已有专项与按需历史

旧`main@7a85481`的`de1a96ae`真实炮口/光束目标、`551846a7`背景专项结论仅覆盖当时范围，保留[资产记录](history/stage6-assets.md)与[278项删除清单](12-asset-recovery-deletions.txt)。不扩为新模块、完整包络、完整玩法、音效或目标机性能通过。

| 问题 | 固定历史来源 |
|---|---|
| 页面/保存/改造/会话 | [集成与保存修复](history/stage6-integration.md) |
| 旧最大负载、10倍、限帧与MAX | [性能测量](history/stage6-performance.md)、[战斗审计](history/stage6-combat-audit.md) |
| parent身份、C/CR、容量旧分歧 | [战斗审计](history/stage6-combat-audit.md)、[裁定](review/conflicts.md) |
| 第5阶段、早期基础职责 | [阶段历史](history/stage5-handoff.md)、[foundation历史](../../foundation/HISTORY.md) |

旧存档不要求兼容的决定保留；旧“配置指纹不匹配一律拒绝”与后来的保存去耦在D9待核，不据旧11摘要重新增加绑定。构建/发布/启动命令只见[foundation](../../foundation/README.md)。
