# 11 当前制作与验收边界

[唯一入口](README.md)。本文只维护本次取回的固定快照与覆盖边界，不定义玩法/布局或授权运行测试；版本更新必须重新读对应源，不拿表格代替他人WIP现场。

## 当前固定版本（2026-10-31 UTC）

| 组 | 独立分支与固定版本 | 当前一步与覆盖边界 |
|---|---|---|
| main | `e3b38d7b6d8256f6031e1b086c7db7812b6a441f` | 仅已合入基线；不含下列所有最新制作，不是最新设计决定的总和 |
| 整体 | `design/clear-zone-host@5df3d3dd59cf4fcd427f0fb9e719ad3a0a9e6969` | [R3入口](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md)：方向已认可，059ac公共运行材质已固定；3c公共有限状态获原独立整体审核者所见无阻断；5df已装装备/B01，但所用7dfa/519f均已有后续退回，依赖原组返修；组合不获默认通过 |
| 装备 | `art/equipment-materials-main-20261029@bb4c7bceb39ef9c8f014662bd767ebca9008bde5` | [逐槽入口](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md)：运行81744已接R3；用户16:24已退回7dfa：舰名牌侵台、控件贴边/行内关系、等级弱、顶部倍率须同步下槽；原组返修中，新WIP未取回 |
| 反应堆 | `implement/reactor-centered-godot@3b2c31e2e1b525d7c8ffc1fc4935dc5b2f31f284` | [B01入口](../verification/reactor-centered-godot/evidence/b01-redesign/README.md)：519首版由根16:06整页退回；R4l返修已有作者同版八态/连续片与保效果缓存诊断，原视觉审核和用户确认未取得，目标机性能未证 |
| 星球 | `feat/planet-single-side-ui@a40cbae14204f68254f46e0b2a69bb51ac5d00aa`（文档）；源码`662952f7c12a1f1a83412cdab4a6cefb683a7ae5` | [R17入口](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md)：原协调07:31快照：站/炉试装已撤回，换完整形体路线；下一独立项环下暗层/自由端；整数Owner试合已撤回，待逐方法整合；本整理未读其未提交现场 |
| 后台 | `feat/amount-safe-previews@c38f1c2b06478d1d8b6e98b8571240e693e296fc`；资源实现`f9244a30ad1843128aaa0a620c4dc3e4866685b2` | [资源契约](contracts/resources.md)：奖励校验/chrono退点获同一Astra限定只读复核；91项是作者证据，非全局实机/独立复测/main验收，D9去绑定已在c38实现、同一Astra仅源码定向核对，main/四组待精确合并 |

四制作组均未整体完成或合main。以上分支不是同一运行版；禁止把不同源码、资产、旧静图/片或局部通过拼成整版验收。本整理树仅保当前制作所需；截图/日志/历史归因已物理隔离，不挂历史导航。main及各原组尚须消费此整理，不能把独立文档分支当成它们已清理。证据审核主体与范围见各入口。

## 当前依赖与判定

- 公共材质：6e0/059ac最小接口已由装备7dfa与B01 519f消费；5df已在3c公共状态上组合装备/B01，同版新组合仍待原整体审核者判断，不强制三分支立即接公共壳，不继续等待Figma。
- 图标：R3静态截图裁片带旧底已定位；按ID用原alpha纹理。透明标准、费用两键、数字/资源显示只在[13](13-art-interaction.md)，模块交换只在[14](14-ui-contracts.md)。
- 资源：以f924必要Owner差异精确合并，不能从后台旧树覆盖新UI；公共兼容行格式或装备helper窄接不代表全局结算/显示完成。
- 不确定项见[裁定清单](review/conflicts.md)：C4身份/保存水位、首槽双零判定仍未决；D9已裁定撤销配置查询包装和保存配置绑定，规范已纠正，后台c38实现已符合本项源码只读核对；main/四组及旧断言仍待原组接入/清理。D10取消确认/还原、D11环带整体方向与按需差异已按用户原话关闭旧要求冲突，未完制作及验收仍保留。
- 证据判断按[07](07-verification.md)与[13§6](13-art-interaction.md#6-制作与双审证据口径)，整页视觉不能以清单清零、API存在或文档整理替代。旧阶段测试禁令/提案不变成本任务命令；本次只核文档及全游戏实现来源，不运行游戏/复测。

## 当前保留边界

真实炮口/光束目标、背景专项已合入的行为保留，不因文档归档恢复旧资产；专项结论不扩为新模块、完整包络、音效或目标机性能通过。D9去配置绑定已在后台c38落实、尚未合main/四组，不能继续以旧规范为保持严格匹配的理由。构建/发布/启动命令只见[foundation](../../foundation/README.md)。
