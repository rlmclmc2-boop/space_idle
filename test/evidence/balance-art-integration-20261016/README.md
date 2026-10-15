# 平衡分支接入开局美术：定点验收证据（2026-10-16）

## 来源与边界

平衡基线 `a5fa51bdae92c817caab1071a8b2a4242c0e503b` 与 Astra 美术 `86c45296fab0f7d35372ade280fe9967b8249c97` 均从 `b6ab391e28ca55eb39827f95821bf94d95c8c8bb` 派生；无冲突合并为 `25fa50757ad4317f2d0a5c34154f11ccc26a81d7`。美术没有改平衡 Excel、`game_data.json` 或原生 kernel。全部运行在 D: 隔离项目，关闭存档、开启生产统计缓存。Godot 为 4.7.2，DLL SHA256 `62176b7a7e1ab372004356ec42db06b8e5c321eb325f591021dac9b62d14fd4b`。资源哈希见 `art-input-sha256.json`；增量编译原始输出见 `native-dll-rebuild.log`，Godot 导入和完整场景运行的原始输出见 `balance-art-{before,after}-{import,stdout}.log`。

## 开局真实场景与事件

最初四场 2-1、2-5、3-5、3-7 的 120 tick 截图试验，均准入原生且无回退；但最初测试夹具给第 2 关装备了第 3 关才解锁的磁轨炮与护盾。因此 `native-opening-cases.jsonl` 和无 `legal-` 前缀的截图**只证明短时渲染和准入，不证明正常开局体验**。随后按已通关关卡重建解锁：第 2 关仅用激光、导弹、装甲；第 3 关才加入磁轨炮和护盾。重新截取的 `legal-native-opening-2-5-t60.png`、`legal-native-opening-3-5-t60.png` 同时显式接入原生显示适配器，展示合法装备与实际敌舰识别框。截图上的 FPS 值受脚本人工推进方式影响，不用于性能判断。

`authored-event-closures.json` 为这次合法装备下、真实 `main.tscn` 和权威遭遇的逐事件及状态证据，完整 stdout 见 `native-event-{2-1,3-3,3-5}.log`：

| 战点 | 执行器与窗口 | 实际闭环 |
|---|---|---|
| 2-1 | 原生、75 tick | 发射 24 次，敌机受击 1 次，UID 6 在 tick 73 死亡；tick 75 保留显示记录 `alive=false`、`visible=false`。敌机词典仍在数组内但 `hp=0`，不能写成“已移除”。 |
| 3-3 | 旧执行器、180 tick | 发射 11 次，敌机受击 4 次；反应型 UID 1 在 tick 82 叠层 0、系数 1.0，在 tick 97 叠层 1、系数 0.8；哨兵 UID 2 在 tick 91 死亡。 |
| 3-5 | 原生、248 tick | 发射 19 次，敌机受击 11 次。护盾初始 1080，tick 82 受击后 980，tick 104 降至 260，至 tick 180 无回升；tick 181 再命中并清空，此后连续命中。护盾延迟 1.8 秒，没有出现足够长的空档，故此例证明持续受击打断恢复，**不证明空档后的恢复斜率**。tick 248 敌机死亡，原生以 `wave_complete` 正常移交；之后显示记录不可见。 |

3-3 不能算原生反应叠层通过：相同合法关卡/装备在原生 `SpaceCombatKernel.configure` 返回 false，尽管编译描述符无 error、人数为 2、drop 规则完整、能力门槛通过。`native-reactive-admission.log` 记录了这个拒绝；对 `a5fa51bd` 的同一一帧准入探针 `native-reactive-admission-before.log` 也得到 `configured false`，因此这是合并前已存在的限制。该机制的事件闭环目前仅由旧执行器证明；修正原生准入属于独立的执行器工作，不在本次美术/恢复数值合并中冒改。美术自带实例生命周期检查 `art-lifecycle.log` 为 33/33，涵盖同 slot 新 UID、舰型/武器/护盾条/碎片与旧实例不串用；它不推进原生战斗。

## 完整场景帧证据的真实覆盖

`rich15-visual-identity.json` 是在两份现成的隔离性能项目中按原驱动创建真实 15 名 actor 的一帧探针，原始 stdout 见 `balance-art-{before,after}-identity.log`。15 名全部是 **scout**：合并前均解析为 `enemy_1`，共 1 张 `res://assets/ships/enemy/toon_v1/enemy-scout-1slot.png`；合并后均解析为 `enemy_opening_triangle_physical`，共 1 张 `res://assets/ships/enemy/opening_v1/triangle-physical.png`。因此下面的计时只比较这一个新舰型纹理，**没有覆盖其余新纹理的性能**。

成对样本使用相同 Godot/DLL/驱动、固定随机种子、完整 `main.tscn` 与 UI、原生 rich15、保留敌机显示；各预热 240 逻辑步，再采 240 逻辑步约 4 秒。速度 1×、帧上限 60、VSync=0；首尾焦点均为真，逐帧 unfocused=0；两侧均为 797 次开火、4527 次受击，handoffs=0。逐帧数据及配置为 `balance-art-{before,after}-full-frame.json`。

| 指标 | 合并前 | 合并后 |
|---|---:|---:|
| 实际逻辑步/秒 | 59.925 | 59.937 |
| 帧墙时均值 / P95 | 16.757 / 20.341 ms | 16.754 / 20.323 ms |
| 主场景 `_process` 均值 / 中位 / P95 | 4.682 / 4.004 / 7.490 ms | 4.720 / 4.000 / 8.466 ms |
| 每帧平均 primitives / draw calls | 96,456 / 999 | 98,277 / 850 |

真实逻辑节奏与帧墙时接近。主场景均值高约 0.038 ms、P95 高约 0.976 ms；单个 4 秒样本不足以判断尾延迟趋势。帧墙时包含限帧及系统等待，也包含其他 CPU/渲染工作，不能把 16.75 ms 当作战斗 CPU；没有独立 GPU 提交或等待计时。原驱动采样后的弹道观察器假定每个 fire 事件都有 `shot`，原生 compact laser 并非如此；配对模式仅跳过该采样后观察，不宣称弹道几何通过。

## 结论与未决项

现有证据支持：合法解锁下所选 2-5/3-5 画面、原生 2-1/3-5 实际命中与死亡显示、旧执行器 3-3 反应叠层、以及单一 scout 纹理的短时完整场景计时。原生 3-3 反应型准入仍被 kernel 拒绝；护盾空档后恢复斜率、其余新纹理性能、前三关共 18 个战点的节奏和资源仍未经验收。未进行新长时试玩或大矩阵。父线程放行前需重读其专用 `PROJECT_CONSTRAINTS.md`。
