# M7 星球

[全局呈现](../../13-art-interaction.md) · [资产来源](../sources.md) · [模块接口](../../contracts/planet.md)

### M7 星球探索、轨道设施与领取

**目标。** 批准的实体环带与四设施形成共同装甲承力形体，独立建造段闭合；球与环独立转，探索船另轨，保持真实球后遮挡。结构可复用并适配不同星球接点，有需要时可单独设计变体。批准图为[实体环带完整态](https://github.com/rlmclmc2-boop/space_idle/blob/c46c1b2e6d3470b972b0f6444900dc3373a8335e/space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)及[闭环分步](https://github.com/rlmclmc2-boop/space_idle/blob/c46c1b2e6d3470b972b0f6444900dc3373a8335e/space-battleship/docs/game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-stages-closed.png)。

承力环进入、穿过并离开设施节点壳体；逐建端面闭合，前弧暗缝与工作端口清楚。完整态应读出站/炉低位通道、炉双料斗和接收口、工坊工作口与移动工具、船坞停靠艇及站顶运动件；第6类球环空隙和远景身份与整体形体相称。

**操作布局。** 建筑用于观看和状态表现；星球选择、探索、人员、自动设置和设施入口集中左侧紧凑操作簇，详情从同侧展开，右侧供观看。选择入口位置稳定，展开后任务摘要和停止/取消仍可达；圆外控制区避让空间站、轨道物体与抵达路径。设施待领提示可发现，收起时释放空间；背侧或遮挡对象仍由稳定入口选择。

**输入与反馈。** 读取Owner的未达门槛、building、缺人暂停、ready、已领取及命令标签；显隐、施工、可领和实际收益分别映射这些状态，规则见[03§5](../../03-progression.md#5-星球探索与建筑)。设施、探索和人员展开区各展示当前对象自己的事实。探索度D、elapsed/duration、设施work/required_work分别命名；切球重绑选择、选项、人数、领取准入与指令目标，清旧短暂反馈。重铸入口连接[M10](persistence.md)。

**完成标准 V7。** 原尺寸完整场景及受影响角度/连续动态中，共同形体、独立建造归属、前后遮挡和稳定控制簇成立。抽屉开合、选择设施、人员/施工/待领/领取、切球及停止/取消反馈，均对应同一对象ID和已接纳事实。
