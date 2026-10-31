# 升级操作组两态协调候选（保留3916信息）

用户已撤回进一步信息精简：“不用进一步精简，看没啥可精简”；继续修同页未选择/选择替换时底部升级变两套及未选右侧空域。固定运行源码 `304883fbde448cd32fa288ae97967e43100209bc`，信息基线 `3916ffbc9e246f07693a633a772536faad982258`。本版没有隐藏防御购级、没有将主值复用为候选容量，不恢复Figma依赖，也不把旧内部审或0失败当用户接受。

## 同版真实整屏

9张完整1440×900根viewport与4张原像素局部共13张均已实际view_image，无拼贴或缩放界面。相同武器/防御同物与异物直接对照，不混不同状态解释字段增删。

| 状态 | 完整整屏 | 原像素局部 |
|---|---|---|
| 独立新局原始状态，未解锁纯空位 | [00](00-fresh-current.png) | — |
| 武器同物，Lv19双资源 | [01](01-weapon-ready.png) | [局部](01-weapon-ready-local.png) |
| 同武器选择异物 | [02](02-weapon-replacement-ready.png) | — |
| 同武器升级费用不足 | [03](03-weapon-disabled.png) | [局部](03-weapon-disabled-local.png) |
| 防御现装护盾，同物 | [04](04-shield-current.png) | — |
| 同防御选择装甲 | [05](05-armour-replacement-ready.png) | [局部](05-armour-replacement-ready-local.png) |
| 真实安装装甲后回购级 | [06](06-armour-installed.png) | — |
| 选护盾，原10秒冷却锁态 | [07](07-shield-replacement-cooldown.png) | — |
| 原Batch当前状态 | [08](08-batch.png) | [局部](08-batch-local.png) |

## 实际根因与本次处理

3916继承的操作区在未替换时购买宽632、选择替换后宽292，倍率键仍留原处，购买文字中心因此横移170px，且同漆面被拉成不同比例；看起来是两套升级操作。仅把台体一律288并固定左行又会放弃未选右侧空间，本次最终没有采用该机械草稿。

现倍率96×36、购买292×36、间距12是同一组、同一节点和同一缓存样式。无替换时整组在底栏居中；选择异物时整组让到原左栏，右侧显示原安装。global两态数量/购买x分别204/312与36/144，y均828；组内关系及面材、字阶、状态源不变，不再632拉满按钮。原内容决定台高266/288响应保留，避免锁死尺寸。

无比较/安装时，右区已有候选使用120高卡/72高同漆面承托，正式武器图48×64、防御图64×64；有比较时仍100高卡/52高承托/44×44图，为原比较留位。只有原节点几何按状态改变，仍同一个EquipmentSurface和face_texture、同一切角/光照/焦点；没有新皮肤、盖片、字段或说明填空。无替换候选占原128/150px可用高度中的120px，底部居中组两侧各188×36留白；新局三个未解锁目录空位仍按用户要求纯空、不交互，不以装饰填满。

## 信息与已取消WIP的界限

相对3916，_refresh_comparison、_render_costs、_refresh_cooldown及所有命令/数量/刷新函数逐字不变：左侧一直显示现装当前→升级后、真实升级费用、倍率/购买；右侧异物仍含原现装/候选比较和安装。防御05仍750→900、65铁，另比较750/1000；65铁属于当前护盾槽购级，未当安装费。武器原周期/攻击比较不删、不加新字段。无记录、用户取消卸下、未锁纯空位、资源icon_modulate原色、舰体/泊位与公共宿主边界保持。

已取消的80692b00防御上下文精简（藏购级/复用候选主值）在原tmp完整保存源字节/patch/json后以0c8088ca可逆revert，恢复panel逐字3916。f7345dee固定288的中间草稿也被最终响应方案覆盖。二者只作为Git历史保全，均非当前候选或新功能，未使用其采图作本版证据。原/tmp/equipment-defence-context-final图未实看/未归档/未推，绝不混进本文件夹。

## 证据与边界

[源边界](source-boundaries.json)核60个其余顶层函数逐字3916、14项业务/宿主/原材质/防御SVG/helper资源图集逐字原版；仅_setup_materials中的原Surface候选高度一式、_layout_workbench操作组/右卡几何、_refresh_choices状态几何签名变化。候选仍缓存原节点和选项，只在真实选择状态变化时适配几何；自然钱包变零过程refreshes/option_reads/candidates_updated增量均0。

原4.7.2/main.tscn/Session/native必要过程exit0，`EQUIPMENT_UPGRADE_GROUP_VISUAL_COMPLETE failures=0 stages=9`；check-only exit0。00来自真实隔离新局、未造开放/余额；01后受控开放/Lv19/有限钱包准备。一次实际GUI装甲安装ok=true，现装/native容量随之更新，观察到原10秒冷却，未等待到期。[原操作记录](visual-operations.json)含每态节点/样式instance ID及真实几何，不以这些参数代替看图。

按本轮要求补[选择往返原记录](selection-roundtrip.json)：同版原main/native真实GUI武器与防御的现装→候选→现装，保×10 mode、钱包、节点、normal样式实例、96/292/12规格，exit0/0失败；没有新截图、购买或换装提交。它仅补原选择动作，不是独立交易矩阵。

本轮没有购买/独立全链/36、冷却到期、长期自然进度、全舰全槽、极端MAX、focus/hover/pressed矩阵、Windows-DPI或共享组合新跑。当前供根/原唯一Astra整体审，未自判空间或样式品质通过。保原目录/art分支/cache/未跟踪/tmp，无新代理/任务/工作区/素材；Figma取消不再调用。本SOL未实际上下文压缩，不pushmain/Library/Space。
