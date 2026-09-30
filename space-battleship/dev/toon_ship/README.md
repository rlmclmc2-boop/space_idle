# 五舰混合武器表现原型

仅开发场景 `res://dev/toon_ship_test.tscn`；正式 `main.tscn`、玩法、数值、RNG、存档均未修改。武器仍来自原有逻辑槽位，无人机只是带一个独立炮塔的显示载体，没有 HP、AI、伤害、CD 或新装备槽。

## 隔离运行

需要 Python 3 与 Godot 4。Windows、Linux 均可；显式指定 `--godot PATH`，或把 `godot` 放进 PATH。仅重新生成 GLB 才需要 Blender。

```sh
python dev/toon_ship/preview.py --godot /path/to/godot --fixture Heavy_Battleship --interactive
python dev/toon_ship/preview.py --godot /path/to/godot --fixture all --mode full-loadout
python dev/toon_ship/preview.py --godot /path/to/godot --fixture all --mode mapping
```

`--fixture` 是明确标记的内存合成满载示例，不是当前玩家装备。可选 Frigate、Destroyer、Cruiser、Battleship、Heavy_Battleship；最后一项保留此前 laser / missile / missile / missile / missile / longLaser / cannon / longLaser 组合。其他舰按四类武器顺序安排。没有玩家存档也能复验。

已有存档可用 `--snapshot PATH` 代替 `--fixture`。启动器复制工程和指定存档到 `test/work/toon-ship-*`，隔离 Windows APPDATA/LOCALAPPDATA 与 Linux XDG 用户目录；Godot 保存始终禁用。`--reuse` 只接受该启动器创建的隔离目录。不会修改原工程运行目录或玩家存档。

窗口 1335×859；战场约 391×657 物理像素。每个新舰体不超过该舰原图的不透明高度，并按整队保守宽度限制到战场宽度的 90%，给无人机和普通闲置转向留边距；整队尺寸另行测量，禁止用近看代替实际尺寸验收。

- T / R：Toon / Rim
- S / V：护盾 / 战斗特效
- O：舰体和武器轮廓遮挡保护开关
- B / C / P：原图对比 / 辅助近看 / 暂停

## 单一表现配置

[hybrid_manifest.json](hybrid_manifest.json) 配置逐舰挂点预算：3、3、4、4、5；真实容量由 `BattleGame.active_slot_count` 读取既有配置，仍为 3、4、5、6、8。配置不重复定义玩法容量。

[hybrid_layout.gd](hybrid_layout.gd) 按原槽序扫描有效且非空装备，前 N 件使用舰体挂点，其余各使用一个无人机。重复武器不去重；空槽和非当前舰的尾部槽不生成武器或载体。更换装备会按这个顺序重新排位，逻辑槽号始终保留给炮口与瞄准连接。没有变更时保留现有节点。

[build_hybrid_hulls.py](build_hybrid_hulls.py) 生成五个紧凑舰体和共用无人机，四类武器由 [polish_weapons.py](polish_weapons.py) 生成独立 GLB，保留原炮口与旋转轴。新舰体无内置武器；独立 WeaponMount、TurretPivot、Muzzle 沿用原坐标约定。源码与资产清单包含界限、挂点及来源。

```sh
blender --background --factory-startup --python-exit-code 1 --python dev/toon_ship/build_hybrid_hulls.py
```

## 特效边界与验收

现有二维投射物与光束仍由原玩法决定；开发子类仅替换显示炮口。默认保留效果在舰体上方的原有顺序，炮口仍可能被充能、火焰瞬间覆盖。O 提供实验性轮廓保护：把透明 3D 输出合成到效果上方，让不透明舰体/武器像素遮住效果。代价是本应在前方经过的投射物也可能被错误遮挡，包括炮口内侧光晕；因此没有作为默认修复。此对比不是深度正确的 2D/3D 特效系统，不改变命中时间。完整特效遮挡仍是未解决的渲染边界。

[hybrid_mapping_check.gd](hybrid_mapping_check.gd) 检查五舰预算、重复/空槽/禁用尾槽、配置替换、确定性与只读性。[full_loadout_check.gd](full_loadout_check.gd) 检查真实大小五方向、180 个炮塔转向采样、整队界限、逐槽炮口、暂停表现操作的状态/RNG 不变、无变更节点复用和移除/恢复；随后短暂运行现有效果。截图和事实写入隔离输出，合成示例身份写入 facts.json。它不是性能、存档或全量玩法测试。

## 第一轮外观精修

重型舰与护卫舰加强立体装甲、舰艏和舰尾轮廓；五舰共享深蓝躯干、象牙装甲层级。四武器保持原炮口变换，细分为青色脉冲楔体、红脊双导弹舱、铜色炮体、双叉持续光束。新增细短二维炮口提示只读取现有 fired_at，不产生射击或推进计时。此轮仍是工程内试样，不是最终美术资产；原二维效果合成的深度边界仍保留。

重新生成武器：`blender --background --factory-startup --python-exit-code 1 --python dev/toon_ship/polish_weapons.py`。生成器输出武器元数据，修改资产后将其对应条目同步到 manifest.json 与 hybrid_manifest.json。

## 舰队比例与环绕试样

重型舰显示高度保持前一版的74%，战列舰85%，小舰不再缩小；无人机本体从母舰模型比例1.12改为0.70（上一版的62.5%），炮塔在无人机内单独取1.20，因此武器显示约为上一版75%。这些是视觉参数，不是玩法尺寸。

重型母舰保持固定构图位置，仅作最大1.2逻辑像素的慢速上下浮动与0.65度偏航。为给舰尾下方轨道留白，其固定中心上移；没有新增玩法位移。普通航行仍只推进航程。

重型舰的三架无人机属于独立3D世界节点，沿18秒一周的小幅不同椭圆持续环绕。它们以120度相位间隔起步；各自角速度有小幅有界变化，平均周期一致以避免迟早互相追上。轨道锚点不继承母舰浮动/偏航，炮塔独立瞄准实际目标，显示炮口从真实载体节点投影。没有增加武器槽、伤害、时序或消耗战斗RNG。其他舰保留附近自主驻留方式。

`run_orbit_review.py`运行隔离20秒/600帧连续表现检查，包含完整一圈、模型旋转包络、视口边界、暂停、炮口与状态/RNG检查。录像按显式30Hz表现步长逐帧编码，不能当成实时性能证明。旧`motion_review.gd`记录的是91f56d5驻留版验证条件，不是当前环绕版验收入口。

所有轨道避开母舰，不通过穿模制造前后层次；同一3D视口有正常模型深度，但原有二维武器特效的深度边界未改。

## 脉冲激光单武器特效试样

`python dev/toon_ship/preview.py --godot /path/to/godot --fixture Heavy_Battleship --pulse-fixture --interactive` 使用明确标记的八槽纯脉冲激光合成配装，便于同时看母舰和环绕无人机发射；不是玩家存档。默认混合夹具保持不变。

本轮只替换己方非光束laser的绘制：有限长度亮芯/短暗尾、75毫秒定向炮口闪光、130毫秒紧凑接触形状。原飞行位置投影、开火/命中事件、伤害、CD、速度与RNG保留；旧laser轨迹与通用发射闪光不再叠加。其他武器与敌方效果沿用原实现。每次发射取实际显示炮口，离膛后沿原逻辑行程投影，不跟着移动无人机拖动已发射弹体。

`run_pulse_review.py`捕获同种子、同配装的前后真实战斗过程，逐帧比较BattleGame非对象状态及战斗RNG，并验证绘制只读和暂停。顺序运行产生的资源收据`resource_samples.time`来自Unix墙钟，仅该时间字段在比较时归一化，收据金额与其他内容仍比较。录像是连续30Hz战斗步长捕获，不是实时帧率测量；没有更改弹速来延长可见时间。
