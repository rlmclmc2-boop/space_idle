# 敌人识别审图样板

仅开发预览；未接入主场景。先审核四类防御代表、同舰体物/能进攻挂件与恢复动态，再决定是否推广。基线 `b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f`；配置权威仍为正式 Excel → `data/game_data.json`，本预览只读 JSON。

## 最小视觉映射

| 实际字段 / 上下文 | 舰体提示 | 代表 | 玩家应对印象 |
|---|---|---|---|
| `armourType=2` | 两层厚肩甲、倒角硬边、深色接缝 | 1046 | 物理装甲用激光 |
| `size=1/2` 且原阵型多舰 | 原小舰轮廓、细翼与群体重复；不加盾 | 原组1002，单舰1007 | 群聚用导弹 |
| `shield>0, shieldType=1, shieldRecovery=0` | 两个外置发生器、闭合六边盾线 | 1088 | 大型能量盾用磁轨 |
| `shield>0, shieldRecovery>0` | 三节点、分段盾线；回补时向内流动 | 1017 | 恢复盾用持续光束 |
| `armourType=0, shield=0` | 保留原舰体 | 1019 | 无新增克制暗示 |

防御映射只由防御与体型字段决定，不读取敌武器名或描述里的“laser/cannon”分类文字。`armourType=1, shield=0` 仅用贴身能防结构，不画护盾；例如1016/1057没有盾。中立混合组保留实际各舰结构，不给整组指定“克星”。小型群聚是数量与尺寸共同表达，不把所有小舰标成导弹专属目标。

进攻单独读取 `equipment` 的装备行 `dmgtype`：2为厚单管、黑膛口、局部短闪、实体弹与少量烟点；1为双叉轨、透镜、局部弧光与细脉冲。主样本原装备均为 `laser_mon`；对照中以既有 `cannon-mon` 行搭配同舰体，仅作为预览夹具，不写回敌人配置。最小挂件宽度15屏幕像素，用单管/双叉的结构冗余辅助颜色。炮口与光晕只占局部；防御外线不填充大片发光。

正式接入时，盾轮廓须依据运行时 `shield/max_shield`：破盾隐藏外线；分段填充对应盾量。回补动态仅在延迟已结束、盾量实际增加且未满盾时出现，等待/满盾/死亡停止；不得通过绘制推进盾时钟或改变盾量。预览用1017实际 `.3s` 延迟、`.2/s` 恢复率驱动合成时间线，从40%盾开始；它是动态美术样板，不是战斗结果。

## 重现与证据

```bash
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition --mode board
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition --mode small
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition --mode recovery --frames 34
```

需要图形显示；Linux无显示时可配虚拟X服务器。启动器仅复制六张敌舰PNG、字体与两份JSON到输出目录下隔离项目，用户目录也隔离，不实例化 `BattleGame`。来源为项目既有 Toon 敌舰PNG加 Godot 程序绘制挂件，无外部生成图。

[`board-000.png`](evidence/board-000.png)：四防御代表＋同舰体物/能进攻对照。[`small-000.png`](evidence/small-000.png)：1373×883窗口下原组1002的5列3行及代表舰；572×960战场按1373/1952缩放。舰宽沿用 `main.gd enemy_render_width` 公式，固定护卫舰基准、前景深度1、尺寸随机系数1；1088为BOSS，其他按普通敌人。不是主场景实战截图，不覆盖其他玩家舰基准、入场远景、随机尺寸或所有敌组。

[`recovery.mp4`](evidence/recovery.mp4)：3.4秒、10fps的确定性时间线；左起受击等待、回补、满盾、破盾，同时给近看与正常尺寸。[1.8秒静帧](evidence/recovery-018.png)辅助查看。视频为编码补齐边缘而加1像素右/下边，内容未缩放。不是实时性能证据。

识别检查的限制：正常尺寸能区分厚肩甲、闭合盾与分段三节点盾；小群体主要靠阵型和尺寸。最小炮口结构仍需用户审图，尤其灰度或繁忙弹幕下；预览没有宣称已完成40组识别或视觉验收。父任务须亲自查看图与视频后交用户，未认可不推广、不合main。
