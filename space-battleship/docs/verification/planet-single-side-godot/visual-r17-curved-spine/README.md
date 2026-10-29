# R17 圆滑实体脊梁材质代表候选

这是接续[R16 结构与台座候选](../visual-r16-integrated-spine/README.md)的美术候选。[1440×900 正常主界面完整态原 PNG](evidence/full-ui-stage4.png)来自 Godot 4.7.2、既有恢复端口设置的第一星球四设施 `built` 临时状态；金币和探索度是夹具值。[同版五个建造可见状态](evidence/)及[受影响相位原图](evidence/phases/)也已归档。作者按原尺寸查看，并与用户认可的[固态实体环概念](../../../game-design/art/modules/planet-six/scheme-b/solid-integrated-spine-clearance.png)并排比较。

本版保留真实四段独立 3D 环、球后深度遮挡、建筑自带台座和独立运动规则。环主体换成高细分圆滑截面，深青侧壁与青色外侧光槽围住带受光的暖象牙装甲曲面；结构肋和台座边缘收窄，完整环接头增加曲面套筒。鞍座与环面共用[原始 ImageGen 材质](../../../../assets/planets/orbital_spine/deck-albedo.png)，只作为真实网格的表面贴图，球后环没有被烘成图。Godot 贴图导入启用 mipmaps，SubViewport 使用 4x MSAA；相机与可建造业务未改。材质[生成提示词与原图 SHA](../../../../assets/planets/orbital_spine/imagegen-prompt.txt)、截图 SHA 见[哈希文件](evidence/sha256.txt)。

代表机位的三座工作设施取消通用黑圆座：旧插画底脚的 3D 根点降至本段曲面鞍座，精炼厂两条短入料槽、工坊开放工作湾两侧导轨、船坞泊位双轨分别属于本座已建环段，不依赖其他未建段；空间站保留自身圆形轨道接口。这是本次接口与深度关系的视觉候选，仍待独立审图，不代表原插画已经转换为完整 3D 建模。

受影响相位使用[固定驱动](evidence/phases/selected-driver.gd.txt)给完整态环带推进模拟时间（每帧 `TAU / (96 × 0.045)` 秒），取 0/24/43/51/72/87/96 帧；这是相位采样，**不代表实时帧率或正常运行速度**。作者原尺寸亲看 43/51/87：设施主体不再被环横切，也没有越过本次模块边缘；24 帧前弧中央仍有深色接缝，虽然套筒网格跨越两侧，画面仍可能读成窄断口，需独立视觉复审，不能据此宣称美术已通过。R16 旧视频不外推为本版动态。Godot `--check-only` 退出码 0，`git diff --check` 通过。

刷新路径定向核查：`planet_panel.gd` 的施工 `work/work_fraction` 原先进入详情结构签名，施工数字一变就调用 `_rebuild_drawer()` 清空并重建整个展开抽屉；现只更新原有标签和进度条，锁定设施的“当前探索度”也更新原标签。状态、可领取、人员等结构性变化仍按需重建该抽屉。临时 Godot [控件身份夹具](evidence/refresh-identity-driver.gd.txt)把施工从 1 次推进到 2 次，确认 ProgressBar 的 `instance_id` 不变且文字、百分比更新，[运行日志](evidence/refresh-identity.log)记录 `PASS`。`planet_visual.gd` 中从未赋值的旧 `facility_renderer` 分支已移除；现有 3D `planet_facility_scene.gd` 和 `planet_orbital_spine.gd` 在 `_ready()` 创建节点，`configure()` 改可见性，`update_pose()` 改姿态，定向代码核查未见按帧叠加 Node。旧 GLB 隐藏网格仍为带命名动画 pivot 的资源结构一部分，本次未删除。该结论限于这四个星球文件与上述夹具，不代表全仓所有刷新路径已验证。

## 后续候选：不透明连续截面与定向刷新

此节记录**后续代码**，上方 PNG 与相位结论仍只对应旧版。新候选的完整主界面[五个建设状态原图](evidence/opaque-spine/stages/)、[独立探索船画面](evidence/opaque-spine/stages/scout_separate.png)和[受影响相位原图](evidence/opaque-spine/phases/)均来自 Godot 4.7.2 本轮源码；[驱动与日志](evidence/opaque-spine/)一并归档。夹具把第一星球逐座置为 `built`，并以 `TAU / (96 × 0.045)` 秒推进环相位，只是加速取样，不代表实时间速度或性能。

前弧 24/72 深纵缝的根因是旧环主体窄且低、设施鞍座宽且高，透明材质排序又让两层装甲和外侧光槽错阶。新候选把每个已建段改成同一宽度与高程的真实连续曲面，去掉叠在主体上的第二层鞍座装甲；设施各自的功能接口仍留在本段。环材质改为不透明着色器，并按现有球体遮挡网格的缩放，对相机到每片环网格的射线求球面近交点，裁掉真正位于球后的片元。由此后环依旧在真实空间连续，前弧不再靠透明多层互盖。作者按原尺寸核了 24/72 连续槽线与侧壁、43/51/87 的设施不被环横贯，及完整主界面四设施；这仍是选定相位与一颗固态星球的候选，不冒充新码完整一圈或六类通过。

抽屉结构签名又移除了纯数值 `source_factor`。当前已建精炼厂或工坊的因子标签在原控件更新；看另一设施时因子变化不重建当前抽屉。[两设施控件身份夹具](evidence/opaque-spine/factor-identity-driver.gd.txt)检查当前因子 1.2→2.5 和另一设施因子变化后的 `instance_id`、文字，日志为 `PASS`。这是修代码路径的确认，未曾观察到用户所担心的全屏控件叠层。

本星球余额栏复用整体组 `c4c48282` 的 `src/ui/resource_visuals.gd` 与同批五个 SVG 图标、颜色，按 `balance_rows()` 的资源 ID 原位更新三个固定单元，不在余额变化时创建新控件。星球设施的掉落加成和征服奖励目前只是描述文案，没有可安全映射到资源 ID 的逐项金额；本候选没有猜测图标或改业务。`--check-only`、`git diff --check` 均退出 0；该受影响夹具与代表取图不覆盖其他模块的资源表现。

## 后续设施根部整合候选

根端退回上节 `opaque-spine` 完整态：三座旧设施插画仍像分别摆在灰环上，底脚与短横 BoxMesh 接口未形成整体。本次只改接合处和材质色阶，保留该版的真实连续环、后侧深度裁剪、独立建段和原位数值刷新。[本次完整主界面五态原图](evidence/integrated-roots/stages/)及[关键相位原图](evidence/integrated-roots/phases/)是**本次代码**重新取的；旧 `opaque-spine` PNG 不代表本次效果。

三座设施各用原 R5 body 图片作 ImageGen 编辑输入，改根部为精炼厂入料承接座、工坊导轨封装裙、船坞双泊位主脊；原上部形态与独立动作层仍沿用，但编辑图并非逐像素保持原上部。[原 PNG、提示词、生成路径和 SHA](../../../../assets/planets/facilities_v5/illustrated/orbit-integrated-prompts.txt)已固定。旧三座设施的短横 BoxMesh 接口已删，避免在新根部下面再叠一套外加条；空间站原圆形座保留。环的原贴图与真实网格没有变，只把受光材质适度调整为暖象牙以缩小与未受光 Sprite3D 的色阶差，没把概念图烘成整环贴片。

作者按原尺寸看了完整主界面和 24/43/51/72/87 相位，前弧连续、选定帧未见旧环面横贯设施，三设施根部与环面的接触比旧横条明确。新根部仍是 camera-facing Sprite3D，不能据静帧宣称其成为完整 3D 模型；整合美术仍待审图。相位驱动沿用上一节的模拟时间加速取样，既非实时性能测量，也不覆盖完整动态或六类天体。本次 Godot `--check-only`、`git diff --check` 退出 0，[驱动、日志与截图 SHA](evidence/integrated-roots/)一并保留。
