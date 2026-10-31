# M3 反应炉

[唯一入口](../../README.md) → [全局规范](../../13-art-interaction.md)。[资产来源](../sources.md#s5)；本页只含 M3/V3，须同时遵守全局 2.1–2.3、复用边界及第6节证据口径；[玩法](../../03-progression.md)只读本任务受影响小节，跨模块提交变动再读 [05现行契约](../../05-architecture.md#现行模块交接契约)。

### M3 反应炉供能

**场景/布局/控件：** 以统一控制台外壳组织核心、能源分配区、升级区及管路相连的设备舱，以“核心—主管—设备”的供能场景统领构图，核心是观看焦点，管路将已开放设备组织为可理解的工作系统，延续圆润控制台的场景关系，以功能区分设备身份；旧截图设备造型不作为认可稿。等级、容量/预算、购级费用融入核心控制区，分配与有效增益贴近对应设备；均分、清零、加减/输入可直达，效果读数对应设备，不将机器缩成通用分配表的插图；整体场景依据见[来源S5](../sources.md#s5)；替换设备静态图按下列接口，不冻结旧造型、旧尺寸、重复读数或常驻教学。

**状态/反馈：** 同时区分手动分配量/占比、重铸免费量、有效供能、最终增益。免费量不占手动预算；分配池不能把有效量当已占用手动量。核心、主管及设备动效读取真实有效负载，无供能不表现持续工作；预览值与已生效供能有区别。碎片凝聚未满足开放条件时，设备、分配行和可选项全部隐藏，不保留锁定占位；条件满足后再显示并接入供能关系。其他模块遵守其现行开放规则，滚动后管路与设备仍相接。

**可见验收 V3：** **画面核对：** 无操作时统一控制台、核心—管路—设备舱构成完整供能主体，分配区/升级区融入场景，不能仅凭复用核心和设备图标判定保留完成，工作/停机可辨，分配控制与读数对应实体；步骤/公式不常驻，手动、免费、有效供能与增益不混淆。**操作核对：** 在有/无免费量时执行均分、清零、购级，比较预算、读数和设备工作反馈；额度不足/非法输入保留实际值并给原因；碎片凝聚开放前不显示，开放后正确接入。来源 S5；旧接口坐标不作为硬约束。


## 可替换静态资产契约

本契约允许后续替换设备及外壳静态资产而保持模块身份、布局关系和业务操作不变；本次只定义接口，不生成新图、不接入新资产。旧截图中的攻击、防御、资源设备未获认可，保留的是整体控制台关系。设备功能键与开放条件仍由现行模块提供。

| 接口面 | 资产与布局/表现的约定 |
|---|---|
| 层级与所有权 | 分离控制台外壳/静态场景、核心/主管、设备舱、独立设备、局部工作效果和前景读数/控件。设备图不夹带整套控制台、管路或按钮；共用设备舱不烘焙设备造型。替图只更新对应层及元数据，不改供能预算、开放条件、购级或分配规则。 |
| 画布与可见边界 | 每项提供源画布尺寸、可见主体边界、安全留白及用途锚点；边界单位/坐标原点明确，不能把透明画布当设备视觉体积。布局提供安装框和裁切/遮挡限制，点击区域由控件定义，不由设备图片alpha自动代替。 |
| 缩放与装配 | 根据可见主体边界等比适配安装框，以设备底座/约定安装锚点定位；不逐轴拉伸、不为换图放大整个控制台。静态主体和运行效果分别声明包络，管口接续与必要净空满足后才接受替图；具体安装框、留白和最大包络待定。 |
| 供能接口 | 核心出口、主管接续点、每设备供能入口分别声明语义锚点及其源图坐标/朝向。消费端用同一最终变换投影实体管口与流动效果；设备遮住支管终端时要有明确遮挡关系，不能用视觉近似另算一条流光路径。锚点来自资产/安装元数据，不埋进新业务分支；坐标数值待定。 |
| 读数与操作区 | 外壳和舱体声明名称、分配、有效量/效果与购级/清零等控件的可用区和避让区；文字、数值、费用及控件运行时叠加，不烘焙进设备图。控件仍对应稳定模块ID，换图不改变其命令、输入语义和真实读数。各区位置/尺寸随整体适配定稿，不沿用截图重复读数。 |
| 工作状态效果 | 静态图只表现设备结构，不烘焙运行光、进度或工作粒子。核心、管路及设备局部效果读取真实有效供能/运行状态；无供能、暂停和隐藏遵守全局时钟/可见性约束。每项声明效果挂点、裁切范围及允许遮挡，亮度、强度和时长无定稿依据时保持待定，不能用装饰效果假装推进。 |
| 资源清单与绑定 | 每项记录稳定功能ID/层级、文件路径与版本/哈希、源尺寸/可见边界、安装/管口/效果锚点、目标安装框与允许包络、导入设置和绑定的读数/控件区域。更新的是资源记录和布局元数据；只因换造型不重新写一套页面或业务。共享外壳/舱体与各设备文件分列，缺图/缺锚点标为待交付，不宣称可直接导入。 |
| 导入与验收 | 仓库现有透明PNG/原生SVG可作格式依据，要求真实透明、无烘焙文字/UI、无黑白边或裁掉结构；源像素尺寸、分辨率预算、过滤/mipmap/压缩参数及安装尺寸均需按最终消费尺度确认，不以旧截图或旧逻辑画布冻结。导入后在支持窗口/缩放及工作/停机状态下，按全局2.2和V3核对可见边界、锚点、管口连接、读数/点击区和效果包络；素材存在不等于替换完成。 |

**待交付资产清单：** 共用控制台外壳/控制区、核心安装环境、主管/接续部件、共用设备舱；独立 `weapons`、`defence`、`smelting` 设备及条件满足后才出现的 `condensation` 设备。哪些静态层沿用、哪些重做及每项最终文件路径/定量规格，先在资源记录中确认；不把清单当成本轮已生成或已认可的设备稿。现有 `assets/ui/reactor/README.md` 中 1364×1200、606×204、223×180 等只作旧消费尺寸事实，不是新资产批准规格。

V3替换核对还须证明：同一组既有操作在替图前后引用同一功能ID/实际值，管口和工作效果随新资产正确装配，布局无需为每个新造型重新写业务；未开放的碎片凝聚依然隐藏。下述v1固定接口格式和转换语义；定量安装区、锚点、包络及部分导入参数未确定时，资源记录须保持draft，不能宣称任意新图直接替换即通过。


### v1元数据结构与稳定身份

这是制作/交付/导入期的资源记录约定，不是游戏运行时schema。版本、格式、引用及SHA核对仅用于这些阶段的人工或离线检查；不新增运行时schema、版本或哈希守卫，不要求启动或逐帧验证。前端按已接纳资源及现有布局关系装配，替换资产不改业务。记录采用JSON对象，`contract_version=1`；不兼容记录在交付/导入期说明并修订版本，不把未知版本处理加入游戏运行路径。`status`仅为`draft`或`ready`：draft可对未定值填null，ready要求下表必填项完整、引用有效；null不作为运行默认值。

稳定模块ID仅为`weapons`、`defence`、`smelting`、`condensation`，共享层`module_id=null`；不能用中文名、图片顺序或文件名推断模块。资产ID为`reactor.shell`、`reactor.core_housing`、`reactor.trunk`、`reactor.device_bay`或`reactor.device.<module_id>`；对应布局槽ID在`layout.slot_id`显式绑定（设备使用`reactor.slot.<module_id>`），业务仍按module_id查询/提交。

| 必填字段 | 类型与固定语义（ready） |
|---|---|
| `contract_version`, `status`, `asset_id`, `module_id`, `layer` | int、枚举string、唯一string、枚举string或共享层null、枚举string；layer为`shell/core_housing/trunk/device_bay/device`，与asset_id对应。 |
| `resource.path`, `resource.sha256`, `resource.canvas_px`, `resource.visible_rect_px` | 项目`res://`资源路径string、64字符十六进制string（仅交付证据，不作运行时守卫）、`[int宽,int高]`、`[number x,y,w,h]`。画布宽高和rect宽高>0，rect在画布内；visible_rect是静态主体边界，不能代替效果包络。 |
| `anchors.install`, `anchors.power_in`, `anchors.power_out`, `anchors.junctions`, `anchors.effects` | install必填`[number x,y]`；device必填power_in，承接供能的核心环境/主管提供power_out，主管junctions按模块ID映射端口。端口对象为`{position_px:[x,y],outward:[dx,dy]}`，方向非零。effects为效果ID→源坐标point的map。shell、device_bay等不适用供能的共享层在ready记录中也允许power_in/power_out为null、junctions为空map；无效果时effects为空map，不制造虚假管口/挂点。 |
| `layout.canvas_logical_size`, `layout.slot_id`, `layout.install_rect_logical`, `layout.target_anchor_logical` | `[number宽,高]`、唯一string、`[x,y,w,h]`、`[x,y]`。定义模块页面逻辑画布、安装框及install应到达的点，均非源图像素或桌面物理像素。 |
| `layout.rotation_deg`, `layout.scale_mode`, `layout.max_scale`, `layout.clip_rect_logical` | 有限number、固定`fit_visible`、正number、`[x,y,w,h]`或显式null（不裁切）。具体数值可待定；禁止隐藏的非等比拉伸/翻转。 |
| `regions`, `effects` | 两个必填map。regions以语义区ID映射`{rect_logical:[x,y,w,h],binding:string,role:readout或control,hit_rect_logical:rect或null}`；effects以局部效果ID映射`{anchor_key:string,envelope_rect_px:rect,clip_rect_px:rect或null,binding:string}`。没有该层内容时用空map。 |
| `import.source_import_path`, `import.settings_snapshot` | 现有Godot资源`.import`路径string、原始设置键→原始值的map（bool/int/number/string）。仅记录该文件真实设置，如`compress/mode`、`mipmaps/generate`、`process/fix_alpha_border`、`process/premult_alpha`、`process/size_limit`及SVG实际存在的`svg/scale`；不能用记录回写或覆盖导入设置，也不虚构独立色彩/过滤配置。现有Godot导入设置是唯一权威，记录过时应更新证据；过滤/repeat等现有消费端属性仍在其原位置维护。 |

所有number必须有限，rect和point的数组长度固定，ID在作用域内唯一，资源、锚点及binding引用必须存在。控制区的`hit_rect_logical`必填有效rect；只读区可null，不能把透明边缘自动当点击区域。语义区键：共享控制区用`core_level/capacity/purchase/equalize`，设备区用`name/manual_supply/free_supply/effective_supply/effect_summary/clear/allocation_input/allocation_minus/allocation_plus`；不适用项不生成可见区域。binding是显示/操作语义键，消费端统一映射现有公开模型/命令，不在图片元数据中写公式或可执行代码。

`effects.<效果ID>.anchor_key`只允许同一资产记录内的路径：`anchors.install`、`anchors.power_in.position_px`、`anchors.power_out.position_px`、`anchors.junctions.<模块ID>.position_px`或`anchors.effects.<效果ID>`。ready记录中目标必须为非null point；不支持跨资产引用、页面/regions路径或任意可执行字段路径。引用点、`effects.envelope_rect_px`与`effects.clip_rect_px`均属于同一资源的源画布坐标，rect为绝对源坐标，不是挂点相对偏移或页面坐标；统一经下式变换。页面逻辑裁切只使用layout.clip_rect_logical，不能混用单位。

### 坐标、锚点与转换约定

源坐标以完整资源画布左上为(0,0)，x向右、y向下，单位为源像素；SVG按其声明画布映射为同一坐标。`install`为设备底座/安装定位点；`power_in/power_out/junctions.<module_id>`为语义供能端口。模块页面逻辑坐标同为左上原点、x右y下；正角度按该屏幕坐标顺时针，均匀缩放为正。所有锚点随主体共用变换，不能为管路/光流另估位置。

源点q到页面点的关系固定为：`p_page = a + s × R(theta) × (q - m)`，m为anchors.install，a为layout.target_anchor_logical。先在安装坐标中减m、统一缩放/旋转，再平移到页面a。`fit_visible`选择不超过max_scale、且变换后visible_rect和必需效果包络完整落入install_rect的最大等比s；若无合法正s，在制作/交付/导入核对中退回该记录，不能用静默截断设备作为验收通过，也不为此增设运行时守卫。rect用四角变换后的外接框核对；最后由页面统一的窗口/缩放变换映到屏幕，点击坐标走其逆变换。现有Godot导入设置按process/size_limit缩小贴图时，元数据仍使用源画布坐标，贴图通过源画布归一化UV采样；不能把导入后宽高代入canvas_px再重复缩放锚点。端口outward只旋转并归一化，不平移；相接管口位置一致、向外方向相反，实体管与工作流使用同一组端口。允许的视觉连接容差随最终消费尺寸另定并记录。

纯转换算例（非美术尺寸）：m=(100,50)、q=(120,50)、a=(10,20)、s=0.5、theta=0，则页面点为(20,20)。这只证明坐标语义，不批准任何设备大小或安装位置。

### 元数据草稿示例

以下字段结构可直接供后续资源记录使用；null是尚未交付的美术/安装参数，不是ready资源。示例无对应新图，本轮不创建导入文件。

```json
{
  "contract_version": 1,
  "status": "draft",
  "asset_id": "reactor.device.weapons",
  "module_id": "weapons",
  "layer": "device",
  "resource": {"path": null, "sha256": null, "canvas_px": null, "visible_rect_px": null},
  "anchors": {"install": null, "power_in": null, "power_out": null, "junctions": {}, "effects": {"work": null}},
  "layout": {
    "canvas_logical_size": null,
    "slot_id": "reactor.slot.weapons",
    "install_rect_logical": null,
    "target_anchor_logical": null,
    "rotation_deg": 0,
    "scale_mode": "fit_visible",
    "max_scale": null,
    "clip_rect_logical": null
  },
  "regions": {},
  "effects": {"work": {"anchor_key": "anchors.effects.work", "envelope_rect_px": null, "clip_rect_px": null, "binding": "effective_supply"}},
  "import": {"source_import_path": null, "settings_snapshot": {}}
}
```

转ready前在制作/交付/导入期填齐适用字段、语义区与端口，核对格式/引用及交付SHA，并从现有Godot导入设置记录快照；不据此增加游戏运行时验证。再按V3用真实画面检查供能连接、读数/点击区和工作效果；协议检查通过仍不等于美术或实际对齐通过。
