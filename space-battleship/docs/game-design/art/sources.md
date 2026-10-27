# 资产与实现来源

[唯一入口](../README.md)；按模块指定的 S 编号读取，来源事实不自动构成恢复命令。

## 4. 资产与实现来源核对表（事实）

以下路径相对 `space-battleship/`。当前文件可直接访问；历史文件统一用 `git show b4729b9:space-battleship/<路径>`，不把旧实现复制进当前运行路径。素材来源/许可/生成提示词仍由各 README 维护，不在本篇另建一份提示词。

**复用时的对齐来源记录（规范）：** 在相应资产元数据或消费记录中引用资源尺寸/模型包围盒、可见主体边界的取得方式与范围、约定锚点及坐标系、布局内边距/偏移、点击区域和最终缩放/旋转变换；已有 manifest/接口可直接引用，不重复维护。记录区分静态边界事实与尚未核对的动态包络：S2/[尺寸参考](../reference/ship-scale.md)的源画布、alpha 轮廓和真挂点，S5 的设备管口/管路，S9/S10 的模型原点、设施枢轴及图标，均按各自消费关系核对。缺少边界或锚点证据时标记待核对，不用 PNG 宽高或模型包围盒自动充当可见尺寸。

### S1

**页面骨架**。当前 `src/main.gd::_setup_growth_panel/_setup_shell_overlay/_setup_guidance_panel`、`src/ui/bridge_theme.gd` 形成六页舰桥、暂停与提示；历史 `scripts/shell_presentation.gd`、`dialog_presentation.gd` 提供浅壳配色、菜单/勾选/焦点样式。历史壳不等于必须恢复十二个旧导航入口。

### S2

**舰体/武器/几何**。[舰体](../../../assets/ships/README.md)、[静态预览](../../../assets/ui/ships/README.md)、[武器](../../../assets/weapons/README.md)；以当前 fleet_20261019、enemy/elite_boss_20261020、武器 manifest 和 ranked 装配为准。当前 `scripts/ship_geometry_convention.gd`、`src/systems/battle.gd`、`src/ui/battle_view.gd` 消费链及 11 中的几何/目标修复优先，历史 ship_panel/dev 布局只供预览与槽位表达参考。

### S3

**战斗场景/资源**。[开场背景](../../../assets/backgrounds/opening/README.md)、[路线图集](../../../assets/backgrounds/hyperspace/README.md)、[资源图标](../../../assets/resources/README.md)，当前 `src/ui/battle_scenery.gd`、`src/ui/battle_hud.gd`、`src/ui/economy_view.gd`。开场仅 1–2 段精修可用，3–10 用现有回退；路线图集已在当前 scenery 绑定，README 的“未连接”是旧状态。资源 README 的旧 resource_art 消费尺寸不能代替当前 UI 适配。

### S4

**舰体/装备专用 UI**。历史 `scripts/ship_panel.gd::setup/refresh`、`equipment_tab.gd`、`equipment_card.gd`：模块卡、费用流、冷却、详情/换装与比较；当前 `assets/ui/equipment/` 图标/面板可复用；旧 `assets/weapons/icons/` 已在基线删除，只是历史来源，不列入可复用资产，不为本篇恢复。当前 `src/ui/equipment_panel.gd`、`src/ui/fleet_panel.gd`、`src/ui/attributes_panel.gd` 有命令与属性接口，但没有完整还原旧卡片与比较呈现。

### S5

[父审已查看的整体场景来源：Git b4d2adc8](https://github.com/rlmclmc2-boop/space_idle/commit/b4d2adc8)，项目路径 `test/evidence/seven-parent-20261017/17-reactor6.png`。画面依据是统一控制台外壳中的核心、能源分配区、升级区及管路相连设备舱，效果读数对应设备；只复用核心/设备图标不算保留完成。旧截图仅作整体控制台关系参考；其中攻击、防御、资源设备造型未获认可，不冻结为恢复目标。可另行生成替换静态资产，先按[M3资产接口](modules/reactor.md#可替换静态资产契约)准备；重复读数、永久教学和旧像素尺寸也不冻结。本地精简Git对象未含该提交，短SHA fetch未取回；本条来源可见性依据父审确认，不冒称本轮已重新查看图片。

**反应炉**。[圆润版与历史来源](../../../assets/ui/reactor/README.md)、[旧金属版接口](../../../assets/ui/reactor/interface-contract.md)；历史 `scripts/reactor_panel.gd::setup/refresh`、`reactor_routes.gd`、`reactor_visual.gd` 是供能/分配/局部动效证据。当前 `src/ui/reactor_panel.gd` 为简化控制行；旧 README 中 panel/visual 的名称不表示专用舞台当前已接入。

### S6

**AI 工厂**。[首代工厂](../../../assets/ai_tech_factory/README.md)：背景、八台透明设备、独立探针；历史 `scripts/ai_tech_factory_page.gd::setup/_build_drawer`、`ai_tech_factory_art.gd` 是舞台/选择层来源。当前 `src/ui/research_panel.gd` 已有投入草稿/当前值、应用/还原及自动投入控制。 [hightech](../../../assets/hightech/README.md) 记录另一组已确认悬浮科技造型，不可把两套画面同时当 AI 工厂默认机器。

### S7

**强化**。历史 `scripts/enhancement_panel.gd::create_effect_card/build_branch_drawer/refresh_branches` 提供顺位卡、详情、分支路径；当前 `src/ui/enhancement_panel.gd` 为效果/节点/A-B 选择。共享 `assets/ui/shell/enhancement.svg` 延续强化身份。[旧宝石图集](../../../assets/jewels/premium/README.md) 与其 workshop/toggle 仅为历史资产，不是恢复宝石中心授权。

### S8

**船员**。[身份与徽章规范](../../../assets/ui/crew/README.md)；历史 `scripts/crew_panel.gd::setup/reset_assignment_draft/refresh_actions/member_portrait` 的名册、详情、派遣预览与占用原因；当前 `src/ui/crew_panel.gd` 有人员/岗位/模式与发布端口，专用人物卡和任务反馈仍缺。

### S9

**星球**。[球体/参数](../../../assets/planets/README.md)、[卡通底图](../../../assets/planets/toon/README.md)、[轨道资产](../../../assets/planets/orbital/README.md)、[模型与图标](../../../assets/planets/orbital/models/README.md)。历史 `scripts/planet_panel.gd::ensure_card_content/_show_facility/_refresh_facility_dialog` 提供导航、设施详情和反馈；当前 `src/ui/planet_panel.gd` 已接 `scripts/planet_visual.gd`，不能登记成“待重建球体”。

### S10

**星系**。[现行 GLB 与模型契约](../../../assets/galaxy/v3/README.md)、`manifest.json`；历史 `scripts/galaxy_panel.gd::refresh_detail` 与 `galaxy_map.gd::pick/_gui_input/refresh`；当前 `src/ui/galaxy_panel.gd` 已接保留的 map。 [建筑 PNG v3](../../../assets/galaxy/buildings/v3/README.md) 明确为退役参考，不用它替换当前模型。

### S11

**超空间**。[家族模型/缩略图](../../../assets/hyperspace/README.md)、`assets/hyperspace/icons/` 与 S3 路线图集；历史 `scripts/hyperspace_panel.gd::refresh_details/protection_flags`、`hyperspace_equipment_ui.gd`、`hyperspace_route_ui.gd`、`hyperspace_material_exchange_ui.gd`、`hyperspace_reforge_dialog.gd` 是品质、装备、岗位、费用审阅与保留确认的来源；当前 `src/ui/hyperspace_panel.gd` 有四子页及绑定预览确认，专用图标与改造对照待完善。旧模型 viewport/测试描述是历史事实。

### S12

**保存与档案**。历史 `scripts/save_panel.gd`、`beginner_guide.gd` 可借鉴动作分区；当前 `src/main.gd` 的预览/确认、保存警告与设置，`src/ui/archive_panel.gd`、`src/ui/notifications_panel.gd` 的已见/已读、教程及敌方资料，按 [06](../06-data.md) 与 [11](../11-stage6-contract.md) 定义实际持久化语义。

### 4.1 来源中的已知断链与时效

本次确认以下资产说明仍指向当前树已不存在的规范/工具/夹具：`assets/weapons/README.md` → `docs/ART_GUIDELINES.md`；开场 README → `docs/art/continuous-v2-refinement/...`、`docs/art/parent-continuous-v2/...` 及旧构建工具；星系 README → `docs/GALAXY.md` 和旧 test 夹具；AI 工厂 README 的概念分支引用也不等于当前工作树中的文件。它们只作历史溯源，不能列为制作前必须读取的现行规范。本篇不伪造替代内容，也不通过恢复整套旧文档/工具来补链；实际资产、manifest 和本篇可见要求可继续使用。需追溯原稿时指定 Git 提交与路径，找不到则列 D6。
