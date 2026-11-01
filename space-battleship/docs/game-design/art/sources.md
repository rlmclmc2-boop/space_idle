# 当前资产与消费来源

固定制作源见[11](../11-stage6-contract.md)。源尺寸、可见边界、锚点、变换、点击区及安装尺度由现有资产manifest/元数据维护。

### S1

公共壳/控件：`src/main.gd`、`src/ui/bridge_theme.gd`、`src/ui/zone_shell.gd`；共用材质源为 `assets/ui/public_shell/faceted-controls.svg`，同目录顶轨/导航/勾选资源承担公共壳。模块沿既有节点消费共同按钮/板面及light/dark数字角色。

### S2

舰体/武器：`assets/ships/`、`assets/weapons/`及manifest；消费为`src/systems/battle.gd`、`src/ui/battle_view.gd`和共享几何。尺度见[参考](../reference/ship-scale.md)。

### S3

场景/资源：`assets/backgrounds/opening/`、`assets/backgrounds/hyperspace/`、`assets/resources/`；消费为`battle_scenery.gd`、`battle_hud.gd`、`economy_view.gd`。

### S4

装备：逐槽场景、卡、比较与费用见[M2](modules/equipment.md)。使用现有武器模型及真实挂点。

### S5

反应堆：独立核心、设备与实体管路见[M3](modules/reactor.md)；坐标/锚点和导入见[资产契约](modules/reactor-asset-contract.md)。

### S6

科研：`assets/ai_tech_factory/`与`assets/hightech/`；消费为`src/ui/research_panel.gd`。ID映射见[D3](open-items.md)。

### S7

强化：`src/ui/enhancement_panel.gd`、`assets/ui/shell/enhancement.svg`；呈现见[M5](modules/enhancement.md)。

### S8

船员：`assets/ui/crew/`、`src/ui/crew_panel.gd`；呈现见[M6](modules/crew.md)。

### S9

星球：现行球体/轨道资产、`planet_visual.gd`及R17设施；呈现见[M7](modules/planet.md)。

### S10

星系：`assets/galaxy/v3/`的GLB/manifest、`src/ui/galaxy_panel.gd`和`galaxy_map.gd`；呈现见[M8](modules/galaxy.md)。

### S11

超空间：`assets/hyperspace/`家族模型/缩略图/图标、`src/ui/hyperspace_panel.gd`；呈现见[M9](modules/hyperspace.md)。

### S12

保存/档案：`src/main.gd`、`archive_panel.gd`、`notifications_panel.gd`；呈现见[M10](modules/persistence.md)。
