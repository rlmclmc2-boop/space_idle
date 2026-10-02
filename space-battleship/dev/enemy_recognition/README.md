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

- [包覆修正：小/中/大与旋转极限](evidence/coverage-v4.png)
- [1373×883正常尺寸检查](evidence/small-v4.png)
- [恢复盾等待、回补、满盾、破盾关键状态](evidence/recovery-v4.png)
- [默认包覆检查结果](evidence/coverage-check.json) / [另一间隙配置结果](evidence/coverage-check-custom.json)
- [炮口第二版彩色](evidence/weapons-v2.png) / [灰度](evidence/weapons-v2-gray.png)

复用项目既有Toon敌舰PNG，六边轮廓与炮口为Godot程序绘制，无外部生成图。正常窗口1373×883，572×960逻辑战场按1373/1952缩放；原组1002保留5列3行与全部15个槽位。舰宽沿用main.gd enemy_render_width公式，固定护卫舰基准、前景深度1、尺寸随机系数1；1088为BOSS，其他普通。炮口图使用相同原舰体26.1px/35.3px舰宽，无动态辅助识别。近看仅辅助结构，识别判断以正常尺寸为准。

V3及更早图/视频仅保留历史，已被V4包覆证据替代，不再用于判断完整包覆。分片动态算法保留；本轮只交关键状态静帧。颜色、防御语法、炮口形状与舰体尺寸沿用已认可版本，只修轮廓范围。

## 包覆计算与验证

`envelope.gd` 读取六张舰体PNG全部非零alpha像素的行边界（含像素单元角点），转为凸包；合并当前预览单管/双叉炮口的实体边界与恢复节点。每条六边斜边按点到边的垂直距离求支撑尺寸，不以矩形宽高代替六边包覆。轮廓与实体用同一舰体/炮口变换；半线宽和抗锯齿余量也计入。单层直接包覆实体，实际存在不同类型嵌套时才额外留层间隙；大型舰首前层由外盾包络继续外扩。

默认可见实体间隙2px，层间/前层间隙2.5px，分别通过启动器 `--gap` / `--layer-gap` 配置。检查独立计算各边有符号垂距：全部6种舰体、2种炮口、3种显示尺度、舰体-6/0/+6°、实际挂点45/50/55/60°朝向极限及额外90/180°诊断方向，共1404组。默认配置和3px/3.5px配置均要求全部边满足余量，结果保留JSON；浮点误差容限0.001px。

范围是当前预览的一个武器挂件及恢复节点，未接入正式多炮座渲染；正式接入时须汇总当时全部实际挂件与变换，不用该中心挂件夹具替代。开火闪光、弹道、击中特效不属于防护实体包络。几何通过不替代父任务的实际像素审查。

## 重现

从space-battleship目录执行，需要图形显示：

```bash
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode board
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode small
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode recovery
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode weapons
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-v3 --mode weapons --gray
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-envelope --mode coverage
python3 dev/enemy_recognition/preview.py --godot godot --output ../test/work/enemy-recognition-envelope-custom --mode coverage --gap 3 --layer-gap 3.5
```

启动器仅复制六张PNG、字体和两份JSON到输出目录下的隔离Godot项目，用户目录也隔离。没有游戏机制测试或长模拟。已检查正常尺寸和彩色/灰度炮口像素；父任务仍须亲自审图。繁忙弹幕、入场远景、其他玩家舰基准、随机尺寸及全部敌组尚未验收。
