# 右侧比例、装甲替换与购买可用态返修候选

用户看完fc/784新版实图后明确退回：“右侧太空了，而且装甲替换展示没有，购买按钮亮了之后明显不一致”。本轮原唯一SOL/目录/art分支继续，固定运行源码 `9e420e1c184d355133737a72f716358203ffa51a`，仅equipment_panel15增8删；不把fc内部静态接受当用户接受或本版通过。

## 同版真实整屏与必要局部

8张完整1440×900根viewport、4张原像素局部均已实际view_image；无缩放拼贴。用完整武器、防御和两种购买准入展示原问题，装甲不再由武器图代替。

| 状态 | 完整整屏 | 必要局部 |
|---|---|---|
| 武器同物、购买可用 | [01](01-weapon-ready.png) | [原像素](01-weapon-ready-local.png) |
| 武器替换、购买/安装可用 | [02](02-weapon-replacement-ready.png) | — |
| 武器购买不可用、安装仍可用 | [03](03-weapon-disabled.png) | [原像素](03-weapon-disabled-local.png) |
| 防御现装护盾 | [04](04-shield-current.png) | — |
| 所选装甲、安装可用 | [05](05-armour-replacement-ready.png) | [原像素](05-armour-replacement-ready-local.png) |
| 真实GUI安装装甲后 | [06](06-armour-installed.png) | — |
| 再选护盾、真实换装冷却 | [07](07-shield-replacement-cooldown.png) | — |
| Batch同版可用执行键 | [08](08-batch.png) | [原像素](08-batch-local.png) |

## 查明的原因与实际修改

**右侧比例：** 原候选是36×32小图/36高承托，常态固定顶齐，隐藏安装后下方空着；购买仍只占左292px。现保留原同一台壳和左右内容，把原图放到44×44、同一承托高52、卡高100；无替换时在原右侧可用区居中，既有数量96px＋购买632px贯通下方两栏。有替换时仍左292px购买、右300px安装，候选上移为比较留位，比较在y176，未叠框或填常驻说明。防御仅两个真实候选，按144px卡/152px列距利用原右296px宽；武器仍原4列68px/76px，未把未解锁空位压走或加交互。原266/288台壳高度与船主体/泊位不变，不复活归档大压缩或详情重排。

**装甲展示：** 实看原fc防御图并查Owner，`panel_equipment(defence:0)`原本就返回armour/shield，比较/容量/安装链原已实现；上一批只交武器，属于展示交付漏项。本轮没有重造防御规则。临时受控有效现装护盾Lv1以清楚展示“替换为装甲”，再真实GUI防御槽→装甲候选→安装装甲。Owner比较护盾750/装甲1000、当前槽升级报价65铁，真实安装返回ok=true；随后侧槽、现装标记、左容量与native装甲容量1000一起更新；再选护盾由Owner原10秒冷却禁用。65铁是当前槽购级报价，未伪装成安装价；本次没有购买。临时现装护盾/开放/Lv19/有限钱包经既有恢复端口准备，非自然解锁或恢复满血证明。

**可用态同族：** 原primary整块赭金亮起后与蓝灰模式/暗禁用分离。现购买、安装、Batch执行均使用原同一个face_texture、EquipmentSurface、切角/截面/焦点，主动作面改蓝灰0.38/0.51/0.54、cream字，次操作保0.31/0.46/0.53，禁用保冷暗0.23/0.33/0.38及ccd6d0字；不再独立金色亮面。资源材质图仍icon_modulate原色，与按钮色无关。所有样式仍原初始化缓存，未加素材/多套框。

## 源码与验证边界

[源码边界](source-boundaries.json)核58其余顶层函数逐字fc：Owner读写、刷新调度/失效、两键、构造、报价、舰船几何、主机端口均保留；仅_setup_materials（含绘制类）、_surface_material、_button_tint、_layout_workbench和_refresh_choices几何变化。14个宿主/业务/配置入口/机库/原素材/防御SVG/资源helper图集文件逐字fc。_refresh_choices仍原依赖读取和节点缓存，不把每次数值更新改成全候选读取/重建；此次自然钱包变零过程记录refreshes/equipment_option_reads/candidates_updated增量均0。

[操作记录](visual-operations.json)、[驱动](capture-driver.gd.txt)、[环境](runtime-environment.json)与日志保原字节。固定源码后原Godot4.7.2/main.tscn/Session/native、DISPLAY99/gl_compatibility，check-only exit0、必要视觉过程exit0，`EQUIPMENT_CANDIDATE_BALANCE_VISUAL_COMPLETE failures=0 stages=8`；含一次实际装甲安装，无购买、独立交易全链/36、冷却到期、自然成长、全舰全槽、极端MAX、焦点/hover/pressed矩阵、Windows-DPI或共享宿主组合新跑。焦点源代码保持，但不冒充本轮重采焦点。

本候选交根/原唯一Astra重新按完整武器与装甲整页判断，作者不自判右侧比例、材质统一或用户品质通过。fc/784与f72组合记录保其历史范围，本版尚不能称已接入组合；公共顶栏/宿主仍整体组负责。无main/Library/Space写入，无新工作区/代理/素材批，本SOL未实际上下文压缩。
