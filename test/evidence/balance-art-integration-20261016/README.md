# 平衡分支接入开局美术：定点验收证据（2026-10-16）

## 来源与边界

平衡基线 `a5fa51bdae92c817caab1071a8b2a4242c0e503b` 与 Astra 美术 `86c45296fab0f7d35372ade280fe9967b8249c97` 均从 `b6ab391e28ca55eb39827f95821bf94d95c8c8bb` 派生；无冲突合并为 `25fa50757ad4317f2d0a5c34154f11ccc26a81d7`。美术没有改平衡 Excel、`game_data.json` 或原生 kernel。运行于 D: 隔离项目，关闭存档、开启生产统计缓存。Godot 4.7.2，DLL SHA256 `62176b7a7e1ab372004356ec42db06b8e5c321eb325f591021dac9b62d14fd4b`。资源哈希见 `art-input-sha256.json`；增量编译 stdout 见 `native-dll-rebuild.log`。

## 开局画面与合法装备

最初 2-1、2-5、3-5、3-7 四场各 120 tick，原生准入且无回退；但最初第 2 关夹具装备了第 3 关才解锁的磁轨炮与护盾。`native-opening-cases.jsonl` 和无 `legal-` 前缀的截图仅作渲染/准入证据。其后按已通关关卡重建解锁：第 2 关仅激光、导弹、装甲，第 3 关才加入磁轨炮和护盾。`legal-native-opening-2-5-t60.png`、`legal-native-opening-3-5-t60.png` 为显式接入原生显示适配器后的合法装备画面，stdout 见 `native-opening-{2-5,3-5}.log`。截图 FPS 受人工逻辑推进影响，不作实时性能证据。

## 真实战斗事件与反应准入

`authored-event-closures.json` 保存合法装备的原始短事件记录。原生 2-1 在 75 tick 内发射 24 次，UID 6 在 tick 73 被击杀，tick 75 保留显示记录 `alive=false`、`visible=false`；敌机词典仍在数组但 `hp=0`。原生 3-5 在 248 tick 内发射 19 次、敌机受击 11 次：护盾初始 1080，tick 82 降至 980、tick 104 降至 260，直到 tick 180 无回升；tick 181 再受击清空，此后继续受击。tick 248 死亡并以 `wave_complete` 正常移交，显示记录不可见。此实际战斗证明连续受击能阻断恢复，不能单独证明安全空档的修复斜率。原始 stdout 见 `native-event-{2-1,3-5}.log`。

3-3 初次旧执行器试验的反应型 UID 1 在 tick 82 叠层 0、系数 1.0，在 tick 97 叠层 1、系数 0.8。初次原生准入被严格 schema 拒绝，合并前也一样：Godot 将权威 JSON 的整数 1 读为浮点 1.0。根因、仅在复制的 descriptor 归一化的修复及非法输入拒绝见 `reactive-native-schema.md`、`reactive-native-descriptor.log`。修复后 `native-reactive-event-after.json`/`.log` 记录同一 3-3 的真实原生闭环：180 tick、发射 12 次、敌机受击 4 次、tick 82 叠层 0/系数 1.0、tick 97 叠层 1/系数 0.8，原生显示已接入、handoffs=0。原旧差别局限于此定点窗口，未声称完整关卡等价。

护盾安全空档由同一权威 3-5 敌人建立受控的受损状态：最大护盾 1080、初始 260、修复率 0.08/秒、命中延迟 1.8 秒，武器冷却置于测试窗口外以避免新的玩家命中。`shield-gap-{legacy,native}.json`/`.log` 各推进 240 tick：至 1.8 秒仍为 260；tick 109、1.8167 秒首次增长至 261.44；4 秒为 450.08，符合之后每秒 86.4 点修复。旧/原生逐 tick 最大差为 0，原生无回退。这是定点公式验证，不等于整关体验验收。

美术自带实例生命周期检查 `art-lifecycle.log` 为 33/33，涵盖同 slot 新 UID 的舰型、武器、护盾条及碎片不串用；此检查本身不推进原生战斗。

## 完整场景成对帧样本及覆盖

两组成对样本均在同机串行，使用相同 Godot/DLL/驱动、固定随机种子、完整 `main.tscn` 与 UI、原生 rich15 和保留敌机显示。各预热 240 逻辑步，再采 240 步约 4 秒；速度 1×、上限 60 FPS、VSync=0，首尾有焦点且逐帧 unfocused=0，handoffs=0。帧墙时包含限帧、系统等待及其他渲染工作，不是战斗 CPU；未取得独立 GPU 提交/等待计时。

最初的 rich15 实际只复制 15 架 scout：合并前共 1 张旧 `enemy_1`，合并后共 1 张新 `enemy_opening_triangle_physical`。`rich15-visual-identity.json`/原始 identity stdout 证明该覆盖。其成对数据为 `balance-art-{before,after}-full-frame.json`，不能外推其他新舰型。

新增一次固定混合夹具：从权威敌人 271012 swarm、271019 anchor、271028 shielded 各取 5 架，由生产 `spawn_group` 建立战斗对象，再统一设置压力测试血量。该夹具用于表现回退检查，**不是正常新玩家配装或关卡推进**。原始 `balance-art-mixed-{before,after}-full-frame.json` 中逐 actor 的 `visual_subjects` 证明合并前为三张旧尺寸纹理各 5 架；合并后为 `enemy_opening_triangle_energy`、`enemy_opening_slab_energy`、`enemy_opening_u_energy` 各 5 架。两侧战斗事件一致：777 次开火、4508 次受击；原始导入/运行 stdout 和同帧截图见同名前缀文件。此对照包含新增背景等整场美术变化，不能单独归因于三张敌舰纹理。

| 混合夹具指标 | 合并前 | 合并后 |
|---|---:|---:|
| 实际逻辑步/秒 | 59.922 | 60.193 |
| 帧墙时均值 / P95 | 16.758 / 20.878 ms | 16.753 / 20.316 ms |
| 主场景 `_process` 均值 / 中位 / P95 | 4.629 / 4.000 / 8.244 ms | 4.638 / 3.986 / 7.817 ms |

该单个 4 秒样本未显示逻辑频率或帧墙时恶化；无法由此断言尾延迟或跨硬件性能已验收。原性能驱动采样后的弹道观察器假定每个 fire 事件都有 `shot`，而原生 compact laser 并非如此；本配对模式只跳过采样后的几何观察，不宣称弹道几何通过。

## 未决项

恢复调整与上述美术/原生表现定点可供父审，但前三关共 18 个战点的节奏、资源和长时体验仍未经验收。未做新长时试玩或大矩阵，未合 main。父线程放行前需重读其专用 `PROJECT_CONSTRAINTS.md`。
