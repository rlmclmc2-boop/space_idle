# 身份→R03视觉映射与共享描述最小接法（待父审）

只提案，不挂载ID、不新增敌种、不改碰撞规则或生产资产。当前背景85a04e26与接口核对cc5676f5保留；未合入balance分支，未启动Godot或Windows测试。

权威输入为Sol [fffa4790 FOUR-WEAPON-BUDGET.md 后半](https://github.com/rlmclmc2-boop/space_idle/blob/fffa47902b420a277b21dce98692f6badb569415/test/evidence/weapon-balance-20261015/FOUR-WEAPON-BUDGET.md#minimum-existing-interface-for-astras-presentation-review)。同提交的opening-visual-contract仅补充其既有原型建议；旧18点稿及其数值/摆放不因本提案生效。远端后来有更新，本次按父指定fffa4790审阅，不自动采用后续参数。

## 已闭合的接口事实

- 八对id/archetype_id是**未挂载草案**，两执行器均保留它们；当前41xxx/42xxx/43xxx旧行没有archetype_id，不能按size替它们推定新身份。uid是实例，slot、size、CombatContext.source_id不是敌种。
- Sol分支reactive的hit提供reactive_stacks/reactive_multiplier，可直接表现实际返回值；不从伤害量反推具体免伤量，也不从事件时间接近猜同轮磁轨。此字段尚未合入本表现分支。
- enemy hit.amount含混合损失；absorbed分项不可靠。护盾量/类别从当前敌人读模型取，恢复以实际盾量增长为准，不按计时器假亮。
- fire不保证含shot，原生激光紧凑路径须沿现有绘制/读模型处理。没有可靠的攻击前兆start/end；不新增预测蓄势、危险倒计时或精确窗口条。

## 三个母型，防御类别优先

上轮八个草案ID各配小灯片/甲板差异的提案已撤回，不作为制作规范。三角/宽板/U形仍是轮廓母型；本轮以跨族一致的横向叠甲与纵向陶瓷大面表达armourType，见[六个标准候选与实际缩小对照](../defence-candidates/README.md)。这六张是三族×两种装甲材质，并非六种敌人，也未绑定八个草案ID。

shieldType与当前盾量单独驱动既有状态层；装备/真实事件表达攻击和特殊机制。身份解析与共享描述方案保留，但不以size、颜色或攻击hit.type猜目标防御类别。

## R03资源还缺什么

resource-audit.json是只读图像审计：当前源图是1774×887 RGBA预览图集，三块裁区有真实透明像素，部分可见边界贴近裁区边缘；不是三张已清理的标准生产舰体，更不是已做好的3D模型。

正式输出须按ART_GUIDELINES的887×1774真透明、舰首朝上、安全边距和不烘焙武器要求制作。R03预览源朝下，不能直接接入再叠一次现有敌舰180°旋转；还须核对运行朝向与左上光向。本轮已另制六张标准画布候选，见defence-candidates；未转换生产资源，也不把旧预览裁区当碰撞描述。

## 最小共享接法：一个键、一份描述、既有权威

```mermaid
flowchart LR
  A[已审 id / archetype_id 对] --> B[一次解析 ship_key]
  B --> C[既有 visual_config.ships 描述]
  C --> D[既有 prepare 捕获纹理边界与 alpha profile / 挂点]
  D --> E[不可变 appearance 与空间发布]
  E --> F[retained 与 fallback 绘制]
  E --> G[既有几何权威 / kernel 输入]
```

1. **解析入口只做身份选择。** 建议在构造appearance/空间发布时增加统一解析，优先精确匹配父已批准的id/archetype_id对，取得ship_key。本轮没有任何批准项，旧行、未知对或未备齐资产均使用原enemy_<size>。不在每帧扫描全舰，也不把27000x硬编码进绘制分支。
2. **描述复用原结构。** 继续使用data/ship_weapon_visuals.json的texture、hardpoints、slot_map及现有挂点字段。equipment决定武器；不为图好看改槽位映射的实际炮口结果。texture对应bounds/profile仍由现有prepare捕获，不另写可漂移的第二套碰撞多边形。
3. **共享解析结果。** 建议将ship_key附在已有不可变appearance里（字段名待实现审查），让simulation_geometry_authority的组件/包络入口、retained_enemy_contacts::compile_record、battlefield的预热/fallback/状态条统一消费。appearance签名沿现有方式包含该键与装备；复用shape_revision/source_id发布失效机制，不增加逐帧资源上传或独立渲染器。
4. **保持权威边界。** 原生所有权移交前准备好纹理描述、alpha包络、挂点与朝向；移交后不访问贴图，不另算第二份几何。native actor已有身份字段即可，不为身份选择扩kernel战斗状态。

### 不改碰撞规则不等于新轮廓天然等价

R03宽翼与U形透明空隙会改变输入alpha；按现有算法派生的轮廓/包络可能不同。这轮不更新任何包络，不能承诺直接替换后命中结果不变，也不能给新壳套一份不一致的隐形旧碰撞。

最小后续审查是：对拟正式资产，**只用现有算法**离线列出可见边界、alpha profile、同一挂点/武器变换以及现有几何产物的差异，连同真实落点对照交父审。U形空隙尤其不能仅凭贴图透明暗示弹体可穿过，须以现有权威算法及已审资产一致性为准。如果不兼容，调整资产/结构描述再审；不在表现线程更改命中、穿透、缩放或碰撞算法。未通过时维持旧正式壳，映射仅留文档。

## 最小实施切分（本轮均未实施）

| 部分 | 最小改动范围 | 前置条件 |
|---|---|---|
| 身份解析 | 一个统一ship_key解析入口＋appearance携带结果 | 父确认映射；未批准对继续旧键 |
| 正式资源描述 | 三母型及必要固定变体的标准资产、现有texture/hardpoints/slot_map项 | 资产与现有几何派生产物审查通过；不提前产八种新敌人配置 |
| 绘制接通 | retained、fallback、预热与状态条去掉各自的size硬选，改读共享键 | 同一appearance/几何发布，不分叉 |
| 已有反馈 | 实际装备发射、当前盾量、实际恢复、返回的reactive层数/倍率、真实explode | 对应Sol代码正式进入整合基线；不补机制或猜时钟 |
| 暂不做 | 精确吸收/免伤分项、同轮批次标志、攻击前兆倒计时 | 等独立接口审核；不阻塞基础身份资源工作 |

父可审的是三族共用防御材质候选，以及共享ship_key接法；不是八个独立敌人皮肤、ID挂载、战点配置、数值或新碰撞规则批准。原生帧验收仍由父另行安排。
