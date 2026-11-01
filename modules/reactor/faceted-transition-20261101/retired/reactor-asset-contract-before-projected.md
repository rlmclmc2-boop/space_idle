# 反应炉静态资产交付契约

[M3目标与状态呈现](reactor.md) · [全局资产呈现](../../13-art-interaction.md)。本页维护制作/导入期的资产元数据与装配接口。

## 可替换静态资产契约

设备、核心、管壳、工作层和前景控件分层交付。元数据提供画布、可见边界、安全留白、底座/端口/效果锚点、安装框、裁切区与动态包络。按可见边界等比适配，实体端口与流动效果使用同一变换；文字和数值由原生控件绘制。控件以稳定模块ID绑定Owner。

当前端口/轴向/插入深度由`reactor_ports.json`维护；分面几何由本地Blender生成器导出`faceted-reactor.glb`，部件按稳定ID独立分组，工作结构为独立Mesh。`faceted-layout.json`记录源画布、机台内区、等比变换及生成器/资产SHA；Godot原生读控共用该源坐标。背景覆盖与主体等比尺度分开，不能通过拉伸整机补边。静态主体与工作效果分别核包络，工作状态输入遵[M3](reactor.md)。同版整页检查装配端接、净空、材质和工作/停机表现。

### v1元数据结构与稳定身份

以下JSON是制作/交付/导入期资源记录：`contract_version=1`，`status=draft/ready`。draft可将未定值记null；ready具备完整有效字段和引用。格式、版本与SHA在交付/导入期检查。


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

以下为draft资源记录示例，null表示待定字段。

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

转ready前填齐适用字段、语义区与端口，核对格式、引用及交付SHA，并记录Godot导入设置；最终装配按V3检查真实页面的端接、净空与工作效果。

## 共同视觉方案的可替换边界

当前本组为整体方案提供结构和过程需求，不以现有写实舱室固定风格。运行中的源画布1187×1326、模块内容口808×835及reactor_ports.json为当前安装坐标事实；整体若需改变内容口，由整体组先交新的明确范围，再更新这份坐标来源。

| 交付层 | 可替换内容 | 保持的关系 |
|---|---|---|
| 舱室/背景 | 造型简化程度、色块、材质及光照 | 模块边界、安装位与可见工作区；公共壳不烘入本图 |
| 核心与四设备本体 | 壳体、骨架、玻璃、接口及底座的共同语言 | 稳定ID、预制端口中心/轴向/尺寸/深度、安装锚点和同源变换 |
| 工作层 | 蓄能/场面/物料/晶体的实体阶段、表面与局部光 | 输入、作用区、输出的连续关系；效果包络与本体遮挡 |
| 前景结构 | 约束件、槽岸、玻璃边界、投射足 | 明确前后关系，与工作层共用坐标，不能靠遮片掩接缝 |
| 原生读控 | 总量/均分、分配身份/滑条、升级费用/数量/动作分组 | 同一Owner字段和命令；文字、比例及费用不烘焙入资产 |

过程输入沿现有可见状态、已接纳负载、游戏时间及暂停/隐藏状态。表现过程只组织这些输入，不增添新的玩法阶段、资源计算或触发规则。每个工作过程交明确的输入/工作/输出锚点、时间顺序、零态及低正载表达；具体造型和渲染方法随共同方案选择。工作遮罩、结构遮挡及表面受光可分离，避免把全套高光、工作值和机台烧在一张不能更换的整图上。现有PNG/Shader是当前运行方式，不作为新视觉方案的能力上限。
