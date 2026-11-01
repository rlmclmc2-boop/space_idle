# 11 当前交接入口

[唯一入口](README.md)。制作规范由13/M页维护。以下为2026-11-01固定来源，接替时按[07](07-verification.md#5-实施顺序)更新本组HEAD、WIP与当前一步。接口要求由[14](14-ui-contracts.md)维护。

| 组 | 固定运行来源/交接文件 | 当前工作与已记录覆盖 |
|---|---|---|
| 主线/装备 | `main@61bde20c1d96167624379ceed41cb0293bb00119`；[装备入口](https://github.com/rlmclmc2-boop/space_idle/blob/docs/spec-scope-equipment-20261101/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/HANDOFF.md) | 装备运行源771295dc已按用户授权进入e845ca58；父协调与原独审检查空槽窄修，作者记录受影响入口与完整图。装备本轮完成。 |
| 反应堆 | [反应堆交接](https://github.com/rlmclmc2-boop/space_idle/blob/docs/spec-scope-reactor-20261101/space-battleship/docs/verification/reactor-centered-godot/evidence/b01-redesign/HANDOFF.md)；运行源`0bc17ae48107972c88a84069cf5221bf5c1cbb0f` | 制作整页热流方向、盾场体量及设备/舱室材质关系；作者有同版八态、边界和1×250帧证据，独立整页判断未完成。 |
| 星球 | [星球交接](https://github.com/rlmclmc2-boop/space_idle/blob/docs/spec-scope-planet-20261101/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/HANDOFF.md)；运行源`1ab75b99` | 当前候选为共同环与四设施形体，作者记录六类完整态、累积态与25°/70°图；整体艺术未通过。原线程已停机保全至wip/planet-thread-close-20261101@96de0d84，新整执行线程直接接替。 |
| 公共壳 | [公共壳交接](https://github.com/rlmclmc2-boop/space_idle/blob/docs/spec-scope-host-20261101/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/HANDOFF.md)；运行源`9838e1e77a60f31070bc472e9ed7ca6eca4161ef` | 已接R12固定运行件和e845装备；作者记录同壳完整图及短动态，当前组合待整页判断。 |
| 后台接口 | `feat/amount-safe-previews@3dd45f5761d04251bb55478c34898781f8a4d0c3` | 资源整数与保存去配置绑定等接口由此固定源提供；各消费者的接入范围由本组当前入口记录。强化MAX仍缺具名出口。 |

交接文件为本次文档候选，原组实际消费提交在接入后更新。后台交接见[后台](https://github.com/rlmclmc2-boop/space_idle/blob/docs/spec-scope-backend-20261101/space-battleship/docs/HANDOFF.md)。
