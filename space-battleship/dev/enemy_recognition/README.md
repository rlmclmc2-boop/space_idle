# 敌人识别审图样板

仅开发预览，未接入主场景。基线 `b3767d1452ab0a4c100f3bc4f26d51c7113a6c0f`；正式 Excel → `data/game_data.json` 仍为配置权威，预览只读JSON，不实例化BattleGame、不写玩家存档。未经视觉认可不推广40组、不合main。

## 当前最小映射

采用用户明确指定的六边形防护语法，取消盒状甲片与实体肩甲：

| 实际字段 / 上下文 | 显示 | 代表 / 应对印象 |
|---|---|---|
| `armourType=2` | 橙色六边形防护轮廓 | 1046，物甲用激光 |
| `armourType=1` | 蓝色六边形能量防护轮廓；没有盾字段时不表达可损失盾量 | 小舰1007兼有能防 |
| `size=1/2` 且原阵型多舰 | 保留原小舰与群体重复 | 原组1002，小型群聚用导弹 |
| `shield>0, shieldType=1` | 蓝色外六边盾；`size>=4`舰首加一层局部覆盖 | 1088，大型能量盾用磁轨 |
| `shield>0, shieldType=2` | 橙色外六边防护 | 真实物理盾字段 |
| `shieldRecovery>0` 且有盾 | 保留分片、节点与向内回补；颜色依shieldType | 1017，恢复盾用持续光束 |
| `armourType=0, shield=0` | 保留原舰体，无防护轮廓 | 1019，无新增克制暗示 |

兼有不同防御类型时，舰体层为内六边、盾为外六边，例如1088同时有橙色物甲与蓝色能盾。同类型的舰体/盾共用外轮廓避免重复叠线，破盾后仍保留真实舰体防护。分片填充对应合成盾量，节点流动只在回补时出现；满盾、等待与破盾停止。恢复预览读取1017实际 `.3s` 延迟、`.2/s` 恢复率，从40%盾开始；是美术时间线，不是战斗结果。正式接入须只读运行时shield/max_shield与恢复状态，不从绘制推进时钟或改盾量。

防御不读取武器名或描述里的laser/cannon分类。中立混合组保留实际各舰类型，不给整组虚构克星。小群体由尺寸与数量表达，不把所有小舰标成导弹专属目标。

进攻单独读取装备行 `dmgtype`：2用居中厚长单管与明确黑膛；1用两侧外露的宽短双叉、中间留空与透镜。对照将既有cannon-mon/laser_mon行搭配同舰体，仅为预览夹具，不写回配置。最小挂件绘制单位15屏幕像素，物理横宽约7px、能量横宽18px；舰体尺寸不变。静态图关闭开火闪光、弹道和盾光圈，灰度由Godot材质直接渲染。

## 当前证据

- [四类防御与进攻对照](evidence/board-v3.png)
- [1373×883正常尺寸检查](evidence/small-v3.png)
- [恢复盾等待、回补、满盾、破盾关键状态](evidence/recovery-v3.png)
- [炮口第二版彩色](evidence/weapons-v2.png) / [灰度](evidence/weapons-v2-gray.png)

复用项目既有Toon敌舰PNG，六边轮廓与炮口为Godot程序绘制，无外部生成图。正常窗口1373×883，572×960逻辑战场按1373/1952缩放；原组1002保留5列3行与全部15个槽位。舰宽沿用main.gd enemy_render_width公式，固定护卫舰基准、前景深度1、尺寸随机系数1；1088为BOSS，其他普通。炮口图使用相同原舰体26.1px/35.3px舰宽，无动态辅助识别。近看仅辅助结构，识别判断以正常尺寸为准。

第一版board-000/small-000/recovery-018/recovery.mp4仅保留历史，已被当前证据替代，不再用于装甲样板审阅。当前分片动态算法保留；本轮只交关键状态静帧。

## 重现

从space-battleship目录执行，需要图形显示：

```bash
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode board
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode small
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode recovery
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode weapons
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode weapons --gray
```

启动器仅复制六张PNG、字体和两份JSON到输出目录下的隔离Godot项目，用户目录也隔离。没有游戏机制测试或长模拟。已检查正常尺寸和彩色/灰度炮口像素；父任务仍须亲自审图。繁忙弹幕、入场远景、其他玩家舰基准、随机尺寸及全部敌组尚未验收。
