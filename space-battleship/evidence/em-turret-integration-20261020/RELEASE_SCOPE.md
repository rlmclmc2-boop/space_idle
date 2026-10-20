# 精简发布候选：精确范围

基线 `108080a7`，最终内容来源 `707981f3`。共 **43 个文件差异**，旧候选为229个；这是从基线新建的单提交候选，不继承试验提交。

## 按功能说明

- **最终资产**：8张精英/BOSS静态舰体和1张独立旋转武器，带运行manifest与登记。全部PNG与707字节相同。

- **必要生产表现代码**：`enemy_visual_identity.gd`仅按发布的tier/leader选最终舰图；`main.gd`仅增加展示尺寸读取与绘制fit参数；`enemy_weapon_interface.gd`是14行只读槽/硬点投影，不写配装。108080a7尚无这8个档位，不能删除这些代码而仍保留最终显示结果。

- **隔离展示与测试**：保留已验证QA纹理绘制器、932检查原夹具、最终素材检查；原八舰检查只排除另行严格验证的新行，原配置冻结断言仍保留。没有为减少文件数删测试，也没有引入另一套战斗流程。

- **复现来源**：批准舰体参考、最终空底座atlas、最终emitter源PNG、紧凑输入JSON和导入脚本。覆盖JSON仅24个最终尺寸，不保留旧设计图/HTML/测量探针报告。

- **证据**：仅707末次10张原窗口图、其ranked.json、入口/本清单/等价性JSON；不带重复run.log、summary、历轮报告和旧图。

## 生产代码差异边界

`main.gd`只涉及 `enemy_display_size`、`enemy_display_fit`、`enemy_hull_rect`、`enemy_display_protection_scale`。`enemy_visual_identity.gd`增加 `visual_rank`及变体选图。普通8舰回退/原显示默认值保留；不改攻击、伤害、冷却、装备数量、倍率、模拟几何、中心命中、actor size、编队和主场景。1/2/4仍仅只读接口和原隔离展示。

生产脚本文本差异量：`main.gd` +11/-6行；`enemy_visual_identity.gd` +14/-1行；新增只读 `enemy_weapon_interface.gd` 14行。必要测试为原GDS夹具232行、最终素材检查和原八舰检查的小幅适配；不是另一套模拟/攻击逻辑。

## 精确文件清单

### 最终运行资产与登记（14）

- `space-battleship/assets/ships/enemy/elite_boss_20261020/README.md`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/anchor-boss.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/anchor-elite.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/command-boss.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/command-elite.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/manifest.json`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/reactive-boss.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/reactive-elite.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/shielded-boss.png`

- `space-battleship/assets/ships/enemy/elite_boss_20261020/shielded-elite.png`

- `space-battleship/assets/weapons/integrated_ranked_20261020/README.md`

- `space-battleship/assets/weapons/integrated_ranked_20261020/cannon-rotating.png`

- `space-battleship/assets/weapons/integrated_ranked_20261020/manifest.json`

- `space-battleship/data/ship_weapon_visuals.json`



### 必要表现、只读接口与原隔离展示（5）

- `space-battleship/dev/qa/README.md`

- `space-battleship/dev/qa/integrated_turret_preview.gd`

- `space-battleship/scripts/enemy_visual_identity.gd`

- `space-battleship/scripts/enemy_weapon_interface.gd`

- `space-battleship/scripts/main.gd`



### 必要测试（3）

- `test/check_enemy_base_eight_assets.py`

- `test/check_enemy_ranked_assets.py`

- `test/test_enemy_ranked_art.gd`



### 最终复现来源与导入（6）

- `space-battleship/art_sources/enemy-fleet-20261019/README.md`

- `space-battleship/art_sources/enemy-fleet-20261019/approved-emitter-20261020.png`

- `space-battleship/art_sources/enemy-fleet-20261019/integrated-empty-bases-atlas.png`

- `space-battleship/art_sources/enemy-fleet-20261019/integrated-turret-bases-approved-20261020.png`

- `space-battleship/art_sources/enemy-fleet-20261019/prepare_ranked_assets.py`

- `space-battleship/art_sources/enemy-fleet-20261019/ranked-import.json`



### 末次最小证据与范围说明（14）

- `space-battleship/evidence/em-turret-integration-20261020/README.md`

- `space-battleship/evidence/em-turret-integration-20261020/RELEASE_SCOPE.md`

- `space-battleship/evidence/em-turret-integration-20261020/anchor-boss.png`

- `space-battleship/evidence/em-turret-integration-20261020/anchor-elite.png`

- `space-battleship/evidence/em-turret-integration-20261020/command-boss-turn--35.png`

- `space-battleship/evidence/em-turret-integration-20261020/command-boss-turn-35.png`

- `space-battleship/evidence/em-turret-integration-20261020/command-boss.png`

- `space-battleship/evidence/em-turret-integration-20261020/command-elite.png`

- `space-battleship/evidence/em-turret-integration-20261020/ranked.json`

- `space-battleship/evidence/em-turret-integration-20261020/reactive-boss.png`

- `space-battleship/evidence/em-turret-integration-20261020/reactive-elite.png`

- `space-battleship/evidence/em-turret-integration-20261020/repackage-check.json`

- `space-battleship/evidence/em-turret-integration-20261020/shielded-boss.png`

- `space-battleship/evidence/em-turret-integration-20261020/shielded-elite.png`



### 本任务状态（1）

- `space-battleship/docs/knowledge/archive/cannon-redesign-20261020.md`



## 打包验证与剩余规模

在新分支上运行导入器和素材检查，9张runtime PNG哈希全部等同707。三份生产表现/接口脚本、QA renderer和原GDS夹具与707逐字节相同；渲染metadata仅来源路径改名。截图与ranked.json复用707已执行的932检查0失败结果，本轮未重跑图形或独立复测。详见repackage-check.json。

PNG合计约15.09MiB。文件数仍包含22张PNG：9运行成品、3最终/批准来源、10末次实机证据；其余为必要代码、元数据、测试和说明。这个范围包含最终八舰及炮塔，客观上大于单张炮贴图替换；未用删除测试或代码来降低数量。

复现不依赖51aae1ac/707历史分支对象或已否决设计目录；验证仅使用基线108080a7（及原八舰检查已有祖先）和本分支保留输入。历史SHA仅作来源说明。

## 默认分支状态

父线程对main的快进已被自动审批拒绝，理由为旧候选229文件超出描述范围。该操作未执行；本轮仅生成新的发布候选，未重试默认分支更新，origin/main仍为108080a7。待父审新清单及候选。
