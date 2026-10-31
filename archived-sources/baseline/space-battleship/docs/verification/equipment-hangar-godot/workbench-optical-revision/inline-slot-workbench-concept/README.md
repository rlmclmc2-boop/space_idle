# 装备 R3：当前制作入口

## 目标与批准依据

用户已认可整体组 `42ea4ffc`、14:52实际送达的 R3 共同风格方向，继续在原逐槽结构落实材质和完整原生状态。[批准图与整体依赖](../../../../ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md)只证明静态方向；装备整体、跨页与新 R3 实机仍未通过，不合 main。

## 固定源与现场

| 项目 | 本次可核快照 |
|---|---|
| 分支/文档固定源 | `art/equipment-materials-main-20261029@d799954d2e9c390872e9ac548c6bc541b8050bd3` |
| 排版运行与旧证据 | `22395e3aa67f9684bbf0d05fb503b6f770b77405`；16px同卡文字、数字角色、费用同排、原滚动区收边、删身份续条已交原审，不代表R3材质已接入 |
| 此后源码差异 | 到d799仅`resource_amounts.gd`更新7行；未重录R3证据，不能把22395图称本次helper或R3同版图 |
| 原组现场 | 原工作区/分支继续；未提交WIP、import、uid、缓存由原组保全，本整理未读取或清理其现场 |

## 当前一步、完成标准与下一步

**当前一步：**消费整体固定的R3最小材质包，在原EquipmentSurface、卡、选择器和按钮替换旧面层。需要plate/card九宫格矩形、边距，以及普通/主执行/选择器的normal、hover、pressed、disabled、focus、selected状态；不从截图提纹理，不覆盖整棵主题。

完成标准：保当前同卡字号、同排费用、文字列、武器→防御顺序和真实裁剪；原尺寸早2/中5/晚8、长MAX、双费不足、滚轮/焦点/下拉及端接形成同版本完整整屏与必要动作，再由根/原审按整页判断。旧19图/23.2秒动作只覆盖22395排版，不代R3完成。提交候选后继续未依赖该裁定的接口核对和状态适配；只把需用户选择的具体项记等待。

## 未完依赖与不得恢复的旧要求

- R3公共包已由整体`059ac56b`/`6e0e86c8`固定并交原组；本组仍待消费。已有数字角色190a已消费，不能将旧b17/R1/R2自动当R3。
- 图标方底根因已定位为R3静态源把整屏截图矩形裁片当图标，见[调查与消费记录](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/r3-native-adaptation/README.md)及[像素/源范围证据](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/r3-native-adaptation/icon-source-diagnosis.json)。按稳定ID直接绘原透明Texture/ResourceVisuals.icon；不逐图抠图、不每帧去底。原生装备控件本已走原纹理。
- 整数源以`f9244a30`为准；当前仅更新必要helper，Equipment/Economy相对a83无差；Session chrono和超空奖励未纳入本组。[精确消费边界](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/r3-native-adaptation/integer-source-f924.json)不证明全局整数或main验收。
- 已定免费点即换、立即切回；不恢复10秒换装锁、二级确认、常驻候选半页、身份残行、记录/教学。舰上只有已有武器；防御不加模型/代理/指线。规则见[03](../../../../game-design/03-progression.md)，视觉见[M2](../../../../game-design/art/modules/equipment.md)。
- 更多极端字段仍需装备域真源；不从现有两费样例推定所有情况。

## 证据与历史索引

[22395完整审阅](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/review-card-alignment.html) · [版本账本](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/card-alignment-revision/ledger.json) · [旧排版动作](https://github.com/rlmclmc2-boop/space_idle/blob/d799954d2e9c390872e9ac548c6bc541b8050bd3/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/card-alignment-revision/session-actions.mp4)。自然早期与受控后期/unknown注入分开记，旧局部通过不升级为当前整页通过。

<a id="最新舰上呈现约束用户已定"></a><a id="当前全部待办衔接依赖与执行边界"></a><a id="当前整页一体感修订2941待审"></a>
旧入口锚点迁到本节；[完整历史](HISTORY.md)保留原139行与固定源。追溯按问题查：排版/裁剪、图标源、R3依赖、旧静态提案；不再读取“末几节”或执行历史压缩停工指令。
