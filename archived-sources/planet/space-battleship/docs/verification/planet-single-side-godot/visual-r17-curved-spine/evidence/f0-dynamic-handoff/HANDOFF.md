# 第一固态星视觉组接入边界

源分支 `feat/planet-single-side-ui`，静态外观/结构已获原审认可的基点是 `f0b617f12b7aff2e635da997f1f0fe96177adda6`。本节动态和逐建只增加证据，不改运行代码或已接受素材。目标主线 `origin/main` 在制作时为 `e3b38d7b6d8256f6031e1b086c7db7812b6a441f`（装备组已验收基线）；本分支还含较早的共享宿主、反应炉、装备等历史提交，**不要把整条分支直接合入 main**。由整体组按主线现有宿主与装备端口移入/协调下列星球范围，不能以未验收公共壳覆盖主线。

星球展示运行边界：`src/ui/planet_panel.gd` 是 `Control`，最小尺寸 `760×740`；现分支 `src/main.gd` 给左模块 `808×900`，通过 `PlanetPanel.new(planet_system, coordinate_planet_cancel, publish_planet_claim, command_button, planet_visual_context, crew_system, coordinate_assignment)` 和 `_register_left_module(..., "planet", ..., "planet", "1")` 接入。面板的视觉区域在 `(0,90)`，宽随面板、可用高度至少 500；设施抽屉从 `(22,278)` 开始，宽 276，原位数值刷新不可在工作量/因子变动时重建整个抽屉。共享宿主使用现有 `set_shared_host(...)`、`exclusive_ui_changed`、取消/任务和原生下拉端口；不要在旧层上叠新控件或替换装备组主线宿主。

本组必要运行源码为 `src/ui/planet_panel.gd`、`scripts/planet_visual.gd`、`scripts/rotating_planet.gd`、`scripts/planet_art.gd`、`scripts/orbital_facilities.gd`、`scripts/planet_facility_scene.gd`、`scripts/planet_orbital_spine.gd`、`scripts/planet_spine_opaque.gdshader`，连同其资源引用。主体环用 `assets/planets/orbital_spine/deck-albedo.png` 及 `.png.import`；设施四个 `assets/planets/facilities_v5/{auto_explore,refinery,equipment,shipyard}.glb` 保留命名动画 pivot，`illustrated/` 当前运行引用三张 `*-orbit-broad-planes.png`、`workshop-arm.png`、`refinery-shutter-{left,right}.png`、`shipyard-crane.png`、`shipyard-berth-ring.png` 与相应 `.png.import`。三张大面素材的源图、提示词、SHA 见 `orbit-broad-planes-prompts.txt`，旧失败的未跟踪 `refinery-orbit-supported.png` 不属交付。

资源栏的直接共享依赖是 `src/ui/resource_visuals.gd` 和 `assets/ui/public_shell/resource-{chrono,iron,jewel,matter,uranium}.svg`，使用整体组已认可的 `c4c48282` 图标/颜色语义，三格按资源 ID 原位更新。只协调这些引用的主线版本；不要搬入本分支其他装备或反应炉视觉资源来满足星球展示。

球体外观由各星球 `generated/config.json` 的 `visual` 传入 `planet_visual.configure(id,row)`；`radiusScale`、`axisRatio`、`pulseStrength`、`pulseSpeed`、发光、贴图和云层参数由原接口解释。设施来自该行 `visualFacilities` 的 `owned` 项，四段只按本座 `built` 可见。小天体用 `_render_pixels()` 保留可读的设施环尺度，不能把固态地表贴图硬套到气态/恒星。**本证据只取第一固态星**；其他天体沿已有接口适配，未据此宣称其视觉已通过。本轮没有新前置玩法、建设规则、主线宿主或装备改动。
