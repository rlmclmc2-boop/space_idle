# R15 独立旋转实体环带接入候选

**源码基线：** `feat/planet-single-side-ui@1eda07fd`，本目录证据由本次 R15 修改后 Godot 4.7.2 实机运行取得；不是此前 R14 的 373 帧整圈证据，也不是概念图直接烘焙的贴图。用户批准的视觉参照是[实体承重脊完整态](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)及[五态闭环修正版](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)。本页只说明当前实现和定向复核，不代表整体布局或其他模块的验收。

`planet_orbital_spine.gd` 在一个倾斜 3D 平面生成四段相接的实体脊梁。每段只随对应设施 `built` 快照显示；独立建造和领取规则仍由 Planet 模块决定。相邻已建段共端点且隐藏内部封帽，四段齐备后构成完整闭环；后弧不是图上的断口，真实网格延伸到球后，由现有透明深度球遮挡。开口段保留自身端盖。整条已建环带及建筑以自己的时钟转动，球体表面继续由原 shader 时钟自转；探索船沿原独立 2D 轨道运行。没有把采集、稳定器或运输画面解释为新的资源/建造规则。缩小固态球的模块比例，让整组结构落在 808×810 的画面中；绘制使用现有 R5 设施轮廓和原星球贴图。

[真实主界面五态](evidence/full-ui/)是 1440×900 正常 `main.gd` 界面下，通过既有存档恢复端口临时设置第一星球的 `built` 集合后截图；截图中的货币和探索度是夹具状态，不是实际玩家进度。`stage_0` 为裸态，`stage_1` 至 `stage_4` 依次增加空间站、精炼厂、工坊、船坞；这个顺序仅为允许的示例，不限制实际领取次序。[scout_separate.png](evidence/full-ui/scout_separate.png)取同一全建状态的探索船独立轨道。源夹具见[driver.gd.txt](evidence/full-ui/driver.gd.txt)。

[转动相位](evidence/turn/)为同版直接模块夹具的两个静帧；`turn_0` 与 `turn_2` 相差约 20 秒模拟时钟，能看到设施跟环带移位、球面花纹相对独立。它们不是连续视频或整圈验收。[其余五类](evidence/six-types/)使用当前 `generated/config.json` 外观和同一四设施完整态，检查共享主体在气态、恒星、红巨星、白矮星、脉冲星上的比例/遮挡；这些是模块夹具，不是六类专属新资源或玩法的完成证明。白矮星和脉冲星保持配置中的小核心，环带因此显得较宽；可在后续视觉审中调整类别距离，不应据此静改规则。作者已逐张目视原尺寸 PNG。

Godot 4.7.2 `--headless --path . --script res://src/main.gd --check-only` 退出码 0，日志见[check-only.log](evidence/check-only.log)；实机截图夹具均退出码 0。ALSA 不可用时 Godot 自动使用 dummy audio，与本次画面无关。`git diff --check` 通过。`origin/main@e3b38d7b` 相对共同基线修改了 `src/main.gd`、`src/game_session.gd` 及装备资源/视图；本候选不修改这些共享文件，也未合并 main。图像 SHA-256 见[evidence/sha256.txt](evidence/sha256.txt)。
