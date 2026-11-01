# 11 当前制作与验收边界

[唯一入口](README.md)。以下是 2026-11-01 取回的独立 Git 快照；不把不同分支组合成同版验收，不以此表覆盖原组后续 HEAD 或未提交现场。

| 组 | 固定来源 | 当前事实与审核边界 |
|---|---|---|
| 主线／装备 | `main@e845ca58afd39184c3d4c5743021480e393adf74`；[原装备入口](https://github.com/rlmclmc2-boop/space_idle/blob/cd3365c9fc84d27f4b0e3217a55d1104011e2027/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md) | 本轮装备已按用户授权合 main；原组入口记录根与既有原独审确认空槽窄修，作者完成受影响入口检查。仅装备本轮完成，不扩大为全局资源、其他模块或全游戏验收。 |
| 反应堆 | [原组入口](https://github.com/rlmclmc2-boop/space_idle/blob/749eccd11d6a6c67a91f9a7138c03508481d373c/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md)；运行源 `0bc17ae48107972c88a84069cf5221bf5c1cbb0f` | R12 已有同版八态、边界及正常 1× 250 帧作者证据；尚无独立整页视觉或目标硬件性能通过。下一步由原组处理整页热流、场壳及材质判断。 |
| 星球 | [原组入口](https://github.com/rlmclmc2-boop/space_idle/blob/acccaf4ccc5d75c92d8bf2e585b1b2df1479a259/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md)；运行源 `14e342c1` | 本次取回已推进至 R114；原组仍制作站环共同主轮廓、四设施共同剪影／材质和紧凑恒星远景可读性。当前只有作者受控图与局部观察，整体艺术尚未通过；未读取其未提交现场。 |
| 公共壳 | [原组入口](https://github.com/rlmclmc2-boop/space_idle/blob/2d4cb2af222f44beef263099eb86628526d8c924/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md) | 仅完成 R12 文本源闭包准备，尚未接入 R12 二进制或同壳运行；旧 R5f 运行依赖仍须保留，不能因设计已退役就删仍被预载的资产。未授权本组合合 main。 |
| 后台 | `feat/amount-safe-previews@f2f5b47c0112d741cca3546a2cec8f3c69934ba3` | 仅记录取回版本；既有资源整数、保存去配置绑定及接口合同沿现行规范。本轮未运行或扩大任何独立审核结论。各消费者按自身固定版核接入，不能由后台版本推定全分支已一致。 |

现行规则／接口分别见 [13](13-art-interaction.md)、[14](14-ui-contracts.md)、[05](05-architecture.md)与[06](06-data.md)；尚未裁定的问题保留在[当前问题](review/conflicts.md)。方向认可、作者自查、协调者检查、独立审核及用户验收必须分别注明固定版本与范围。每次接替重新核本组当前入口；旧通过、旧退回和旧“待用户”均不能覆盖新事实。
