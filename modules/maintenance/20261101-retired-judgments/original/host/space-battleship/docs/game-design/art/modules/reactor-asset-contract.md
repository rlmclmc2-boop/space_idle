# 反应炉静态资产交付契约

[M3目标与状态呈现](reactor.md) · [全局资产呈现](../../13-art-interaction.md)。本页维护制作/导入期的资产元数据与装配接口。

## 可替换静态资产契约

设备、核心、管壳、工作层和前景控件分层交付。元数据提供画布、可见边界、安全留白、底座/端口/效果锚点、安装框、裁切区与动态包络。按可见边界等比适配，实体端口与流动效果使用同一变换；文字和数值由原生控件绘制。控件以稳定模块ID绑定Owner。

当前B01端口、设备/工作层裁图与管段图层坐标由运行资产的`reactor_ports.json`维护；安装、导入与最终消费尺度见当前资产README。静态主体与工作效果分别核包络，工作状态输入遵[M3](reactor.md)。同版整页检查装配端接、净空、材质和工作/停机表现。

### 宿主安装与三段控制区内容口

模块根画布为808×900，公共顶轨占y0..65，模块内容为`[0,65,808,835]`；舞台局部坐标y=模块y−65。右侧导航从x808开始。场景、设备和工作包络在模块内容内构图，左右建筑与台体自行完成收边。

三段控制区以底部稳定升级事务带为制作基准。n为Owner提供的可见行数1/2/3/4；台体底边为y888，外台高`173+45n`，顶边`715−45n`，对应670/625/580/535。台体x12..796，内容左右内收16px；总控带高52px、每行45px、升级带高65px，两处组间距各12px，台体上下内距16px。上方场景随实际台顶构图，前景实体及效果包络避让控制区。

| 内容口 | 模块逻辑坐标／排列基准 |
|---|---|
| 总控带 | x28、y=台顶+16、w752、h52；名称、比例条、总量读数、均分在同一带内 |
| 总控带内列 | 名称x44/w88，比例条x144/w288，总量x448/w192，均分x664/w100；均分高36、距带顶8 |
| 分配行 | 起始y=台顶+80；图标x44/w24，名称x80/w96，滑条x192/w360，百分比x568/w88，增益x672/w92；各项按行中心/字形基线对齐 |
| 升级事务带 | x28/y807/w752/h65；等级身份组x44/w144，费用组x204/w332，右侧操作组x552/w228 |
| 数量／升级 | 数量`[568,821,56,37]`，升级`[636,821,128,37]`；组内间距12px，左右可见内收各16px |

以上作为原生排布起点，按实际字体、切角、边光和动态包络作光学校准。台体装甲和凹槽由内容组一起塑形，均分位于总控自身操作区；升级事务带内不另叠独立窄井。公共材料通过现有`BridgeTheme`节点接口消费，dark板面对应dark文字/数字角色。

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
