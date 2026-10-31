# 当前资产与实现来源

[唯一入口](../README.md)。来源用于识别当前资产、消费关系与必要锚点，不是恢复旧布局、玩法或工具的授权。各制作分支最新批准依据与证据从[11](../11-stage6-contract.md)进入。

**对齐记录：**在当前资产元数据或消费记录中标明源尺寸、可见主体边界、锚点/坐标系、内距/变换、点击区和最终安装尺度；可引用已有manifest，不重复维护。静态边界不冒充动态包络，PNG画布/模型包围盒不自动等于可见尺寸。缺少证据时标待核对。

### S1

公共壳与控件：`src/main.gd`、`src/ui/bridge_theme.gd`；当前R3制作与有限状态见[整体入口](https://github.com/rlmclmc2-boop/space_idle/blob/6e0e86c80d7cc7ee4f8623fca929c2f4828b6215/space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md)。

### S2

舰体/武器/几何：现存`assets/ships/`、`assets/weapons/`及其manifest，运行消费为`src/systems/battle.gd`、`src/ui/battle_view.gd`与共享几何。实际尺度口径见[尺寸参考](../reference/ship-scale.md)；不恢复已退役舰模或固定朝向。

### S3

场景/资源：现存`assets/backgrounds/opening/`、`assets/backgrounds/hyperspace/`、`assets/resources/`；消费为`battle_scenery.gd/battle_hud.gd/economy_view.gd`。开场3–10精修仍未完成，已有回退保留；图标读取原透明纹理。

### S4

装备：当前逐槽场景、卡、比较/费用与裁剪见[装备入口](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md)及[M2](modules/equipment.md)。当前已有武器模型/真实挂点继续使用，防御不加代理模型。

### S5

反应堆：按用户批准B01的独立核心/设备/实体管路制作，见[B01入口](../../verification/reactor-centered-godot/evidence/b01-redesign/README.md)。资产身份/锚点/导入条件只见[M3资产契约](modules/reactor-asset-contract.md)，不导航回旧整图舞台。

### S6

科研：现存`assets/ai_tech_factory/`首代工厂与`assets/hightech/`悬浮图集；两套素材在现行研究ID上的具体分工尚待D3定稿，不能同时宣称为唯一默认机器。当前业务消费为`src/ui/research_panel.gd`，规则见[M4](modules/research.md)。

### S7

强化：`src/ui/enhancement_panel.gd`及`assets/ui/shell/enhancement.svg`；顺位/效果/分支见[M5](modules/enhancement.md)。旧宝石玩法未获恢复授权。

### S8

船员：现存`assets/ui/crew/`身份素材、`src/ui/crew_panel.gd`；人物、占用/岗位与任务反馈见[M6](modules/crew.md)。

### S9

星球：现存球体/轨道资产与`planet_visual.gd`、当前R17设施制作；当前批准与原生状态见[R17](https://github.com/rlmclmc2-boop/space_idle/blob/ee802997f84a3627f8f92bdd76fd93ad94676207/space-battleship/docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md)和[M7](modules/planet.md)，不恢复贴地强制分工。

### S10

星系：当前`assets/galaxy/v3/`GLB/manifest及`src/ui/galaxy_panel.gd`、`galaxy_map.gd`；按[M8](modules/galaxy.md)表达真实建设阶段。退役PNG不替换现行模型。

### S11

超空间：现存`assets/hyperspace/`家族模型、缩略图和图标，`src/ui/hyperspace_panel.gd`四子页及领域预览；规则与呈现见[M9](modules/hyperspace.md)。不恢复旧独立友方世界或每卡viewport。

### S12

保存/档案：`src/main.gd`、`archive_panel.gd`、`notifications_panel.gd`；语义见[06](../06-data.md)及[M10](modules/persistence.md)。D9已定去配置绑定由原后台纠正，不恢复查询包装。

### 4.1 来源时效与当前缺口

资产README中若出现已不存在的旧美术文档、概念分支、工具或夹具，不作为前置要求，也不为补链恢复旧依赖。当前资产、manifest与本页具名消费范围可以继续使用；缺少必要来源时记录D6并核实际对象，不凭旧文案扩任务。
