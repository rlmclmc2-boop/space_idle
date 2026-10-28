# 星球旧表现核查与两条渲染路线静态比较

本轮按[唯一入口](../../game-design/README.md)读取M7/S9、相关实现与资产来源。用户已否定上一轮图稿方向：`bc29f59b`及其集中修订`f85e020f`仅保留现场，不继续作为选定方向。f85e020f的提交/推送发生在停止指令到达前；停止后的旧表现核查阶段没有生成新图或改UI。本报告供根线程核对，不选定技术路线、不修改共用规范。

后续用户明确了地表/轨道分工、建筑仅观看/操作独立，以及优先用两侧余量和按需抽屉收纳；当前规则总结见[M7](../../game-design/art/modules/planet.md)，贴附/遮挡成本见[P3分析](../planet-surface-orbit-v3/direction-and-routes.md)，当前两态构图见[P4](../planet-watch-management-v4/README.md)，P3常驻大底部控制区不再沿用。下文保留旧表现核查和球体路线静态分析，不再以建筑点击/追踪映射作为实施需求。

## 1. 实际看到了什么

已下载[固定历史573e9312](https://github.com/rlmclmc2-boop/space_idle/tree/573e9312f6fd6d9257a5e78aa5588b0403751441)的planet-1.mp4、planet-6.mp4及README.txt；ffprobe确认始源星视频为1372×884、120帧、10fps、12秒。按帧号0/40/80/119提取，逐张实际查看两个视频的8张完整画面，未缩放、裁切、合成或重画。原视频与解码帧见[evidence](evidence)，哈希与提取方法见manifest.json。

始源星四个时刻的大陆持续改变屏幕位置，轮廓在边缘压缩、进入/离开可见半球；球体外形和主要光照方向稳定。云纹位置也改变。脉冲星四时刻能看到双极喷流的不同投影朝向，不是一个白球加固定两条射线。观察与下节源码的地表相位、云相位及喷流投影一致；单凭四帧不能量出GPU成本或证明所有极区/接缝情况。

这些是旧正常主场景捕获，状态为隔离目录**合成解锁**，截图内探索未开始、设施未领取。故它们能证明天体动态，不能充作探索机飞行或已领取设施转动的实机证据。原README说明Linux llvmpipe、按页面模拟时钟采样，不是墙钟FPS基准；不能把画面内FPS:1或历史48项检查当用户GPU性能结论。原始客户区1372×883，为H.264多补一行；不得据旧尺寸恢复窄屏任务。

## 2. 旧表现组成与沿革

| 固定版本 | 确认的组成 |
|---|---|
| [569627f8](https://github.com/rlmclmc2-boop/space_idle/blob/569627f85ce3566266cb2b86095783614d1798e4/space-battleship/scripts/planet_visual.gd) | 更早阶段读取成品planet-globe.png；不能把所有旧版本都称为同一技术方案 |
| [4cac4e16](https://github.com/rlmclmc2-boop/space_idle/blob/4cac4e16759ba6050fa1f03c28d250f0dc45d15e/space-battleship/scripts/rotating_planet.gd) | 增加ColorRect+canvas_item球面shader、独立地表/云图、两套相位、固定光照；是贴图运动模拟自转，不是真实球体网格转动 |
| [d7f9a2d9](https://github.com/rlmclmc2-boop/space_idle/commit/d7f9a2d9eadf59f1222342f5e2c8f4bf9b301385)、d2d4594c | 第一星球换卡通等距柱状地表与独立灰度云图，后续五天体沿数据参数保持差异；球面投影仍在shader里 |
| [df10eec9](https://github.com/rlmclmc2-boop/space_idle/commit/df10eec94315e6094da49e826d65e2aa06401908)、ec83d3d6 | 恒星细节两层随同一个表面相位，整数经度重复封接缝；573e9312视频对应ec83d3d6，视觉修改df10eec9 |
| main e93c2212 | 当前仍保留上述球面shader及相位路径，不是待重建球体；新面板用当前快照、paused/speed推进 |

源码定位均以main e93c2212为准：

- [rotating_planet.gd:67](https://github.com/rlmclmc2-boop/space_idle/blob/e93c221239a10d377b2ca89dd395ebcfa99c9819/space-battleship/scripts/rotating_planet.gd#L67)：phase.x/y分别积分地表和云层；可见且未暂停才推进。始源星在planet_visual中采用默认0.006/0.0073圈/秒，差速不是整体PNG旋转；这些是现行参数，不是新建议。
- [shader:45](https://github.com/rlmclmc2-boop/space_idle/blob/e93c221239a10d377b2ca89dd395ebcfa99c9819/space-battleship/scripts/rotating_planet.gdshader#L45)：从屏幕圆盘求normal，再用atan/asin求球面UV；地表、云密度及偏移云影分别采样。光照由normal与固定light_direction点积决定，使用柔和卡通明暗带、少量高光及边缘大气；明暗和轮廓不跟地表纹理一起转。**它是二维承载的解析球面呈现，不是单张成品球图，也不是3D网格。**
- [planet_visual:241](https://github.com/rlmclmc2-boop/space_idle/blob/e93c221239a10d377b2ca89dd395ebcfa99c9819/space-battleship/scripts/planet_visual.gd#L241)：可见时按1/24秒累积阈值合并视觉推进（实际更新率受显示帧量化），背景独立静态层；前/后轨道分别绘制，探索机按椭圆及切线朝向飞行，有抵达、短尾迹、扫描、完成光点、离开等表现。球体自转并不以探索running为前提；探索机和扫描才依赖真实探索状态。
- [orbital_facilities.gd](https://github.com/rlmclmc2-boop/space_idle/blob/e93c221239a10d377b2ca89dd395ebcfa99c9819/space-battleship/scripts/orbital_facilities.gd)：设施既有沿轨道的平移，也有独立模型姿态与Motion部件动作；船坞轨道速度为0但有自身姿态/部件变化。旧面板在[ec83d3d6:245](https://github.com/rlmclmc2-boop/space_idle/blob/ec83d3d68f374998c23f474e7d276802f02f31f1/space-battleship/scripts/planet_panel.gd#L245)注入一个1024×256共享3D图集渲染器，再把模型视图贴到2D轨道上；不是整座星球3D场景。

**当前设施接入缺口：** main的src/ui/planet_panel.gd只实例化planet_visual，没有建立/注入facility_renderer；在src和scripts定向查找没有其他赋值。planet_visual因此走Art.facility图标回退，沿轨道的位置/前后分层逻辑仍在，但原模型姿态和部件动画没有这条当前接入链。这是源码确认的接入差异，未跑当前设施实机，不能据此扩大为已实测故障；本轮不修复，也不将其成本错误地算作“模拟自转必有成本”。

## 3. 当前图稿为什么不能承接原效果

图稿虽然把球体放进整片模块空间，但把完整球面、云纹、高光和大气烘焙为一张生成图，设施也只呈现各自一个静置姿态；没有证明大陆过球缘、云地差速、固定光照、轨道背面遮挡、抵达/扫描/领取后变化的连续关系。放大球体和增加小行星装饰，不能代替这些观看内容。

问题不是“模拟自转一定错”，也不是“必须换真实3D才能立体”。之前生成稿没有把旧表现的可动分层及时间维度作为设计对象，且不能作为运行底图直接使用。后续无论选哪条路线，都应复用未打光的等距柱状地表和独立云密度，避免拿带云/阴影的成品球图去滚动或包到3D球上。UI仍须让设施/舰船/操作/读数属于同一空间，不能回到内嵌图片框；技术选择本身不会自动解决构图。

## 4. 两条路线的同条件静态比较

A为现有ColorRect+解析球面shader，移动地表/云层采样相位。B为可复用SphereMesh，用节点变换旋转网格，材质贴同一地表图；网格一次建立，不需每帧重建或物理模拟，也不必新增Blender资产。[Godot SphereMesh](https://docs.godotengine.org/en/stable/classes/class_spheremesh.html)支持配置径向分段和rings。

| 比较项 | A：贴图相位+球面shader | B：球体网格旋转 |
|---|---|---|
| 固定视角、平滑球面、轴向自转 | 已实现地表过球缘、固定光照、独立云差速。几何推断：同一贴图/相位/光源下，可与细分充足的正交网格产生相近投影；采样、极区和抗锯齿仍可能不同 | 同样能达到，**不会仅因用了网格就更真实或更好看**；少分段可能露多边形轮廓 |
| 相机绕转、任意轴倾角、云高度视差 | 现有代码不完整支持；解析球面理论上可扩展坐标基/云壳相交，但要维护额外数学与对齐 | 相机/变换/分层球壳更直接，复杂空间关系与后续扩展有优势；仍须匹配已确认的卡通材质 |
| 当前CPU增量 | 少量相位积分、uniform写入，轨道绘制另算；具体耗时未测 | 单球旋转变换很小；新增场景、可见性、材质、视口提交等成本取决接入；具体耗时未测 |
| 当前GPU增量 | 无球体细分；但逐像素求球面normal/反三角函数，始源星源码有3次map_sample、每次2次texture表达式。shader并非免费，真实指令/采样带宽待测 | 增加顶点变换、光栅化与深度处理，可用网格UV/normal插值省去部分逐像素反算；若走子视口还含目标缓冲及合成，可能抵消节省。谁更快未测 |
| 云层/光照 | 已在同一球面pass合成云与近似云影；不提供真实云高视差或体积云 | 对等基线可在**同一不透明球面材质**合成云，独立云相位相对旋转轴处理；不必默认多画一层。若另加透明云壳/大气壳/阴影贴图，属于新增表现与成本，另算 |
| 设施遮挡 | 当前按front/back绘制顺序，能表达绕球前后，难处理任意相交、精确局部遮挡 | 仅当球体与设施处于**同一深度空间/同一视口**，不透明深度测试才直接解决；球体单独SubViewport再贴入2D，不会自动解决设施遮挡 |
| 资产和维护 | 复用现行地表/云图、数据描述、六天体shader及显示时钟，接入风险较低；复杂几何时数学/手工前后层规则会增长 | 等距柱状贴图可复用、基础球可程序生成；需适配材质/相位/相机/抗锯齿/视口/坐标映射。已有恒星日冕、喷流要有明确承接方案，不等于六套资产全部重画 |

GPU胜负不能用“2D比3D轻”或“单球三角形少”推定。Godot官方强调片元复杂度、纹理读取、透明重叠和硬件差异，应看实际瓶颈：[GPU优化](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)。B若用透明云壳，alpha blending涉及排序、额外覆盖，默认透明材质也不自动提供云投影：[StandardMaterial3D](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)、[Spatial shader透明限制](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)。不把PBR、额外动态灯、阴影、体积云强塞给B，也不能靠删云/降清晰度让其中一方“赢”。

**推进频率陷阱：** 现行1/24秒阈值限制的是相位/绘制命令更新，不是已证明GPU只着色24帧。Godot缓存_draw命令，不能等同缓存整张渲染结果：[2D自定义绘制](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)。根视口持续绘制战场时，现有球体仍可能随显示帧执行shader；实际需捕获核对。B用SubViewport UPDATE_ONCE缓存时可在未更新帧仅合成旧结果，但A也可采用缓存视口，且会新增视口成本；这是缓存策略差异，不是网格的固有优势。[SubViewport更新模式](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)。

当前条件下，A已有完整平滑球面/差速云层的表现基础；B在真正需要变换视角和统一3D设施深度时更有结构优势。**性能、能耗和最终观感胜者均未测，未选路线。** 若仅固定镜头的现有效果，不能假定B必有可见收益；若决定扩大空间表现，也不能只因旧实现已存在就排除B。

## 5. 必要同条件测量方案（本轮未执行）

仅在根线程确定测量范围后执行，不新开任务、不建立独立复测工程、不以本报告启动正式UI。本轮没有编写B、跑基准或修改引擎/业务。

1. **固定工作负载。** 同一Godot4.7.2构建、目标机器/驱动、当前gl_compatibility后端、导出/调试方式；窗口1440×900、模块808×900、右战场状态一致。此尺寸仅是各组共同实验条件，不是main当前尺寸，也不冻结尚待用户确认的最终布局。球体实际可见直径D、中心、采样精度、色彩空间、背景、地表/云图哈希、mipmap/过滤、光源、速度、云影和大气强度全部相同；D先记录各组共同值，不从旧截图或生成稿反推最终尺寸。不能A画D像素而B先低分辨率渲染再放大。
2. **先隔离几何路线。** A解析球面与B单网格各采用同一已定材质效果，每显示帧均渲染、相位时间序列相同，关闭额外PBR/阴影/后处理。B使用一次创建且轮廓达标的最低合理分段，不每帧生成网格；地表不写ALPHA，保持不透明，云同材质合成。记录B实际视口、深度、合成成本，不能只量旋转函数。
3. **再公平比较部署策略。** 若评估约24Hz缓存，A/B都采用相同像素范围的缓存目标和完全相同更新时序，记录实际更新次数，分别统计更新帧/复用帧及整窗合计；复用帧不能把视口上次渲染的旧计时再次累计。另列当前A直接Canvas合成与拟议B视口接入的实际部署差异，不能把它解释成纯几何胜负。暂停/隐藏均停止推进和无用目标更新，根战场继续原行为。
4. **设施条件一致并分开归因。** 明确三个组：C为当前main设施图标回退控制组；A为恢复同一模型设施及姿态/部件表现的解析球面组；B为使用同等设施质量的球体网格组。三组在相同实验呈现尺寸/状态下记录，保留各自接入事实。C→A只用于记录设施恢复增量；A→B才用于比较球体路线，不能把C→B的差额全部算成网格成本。裸球只作归因辅助，最终A/B必须带同一数量/同一模型、路径、姿态、尺寸及前后经过时序，使用一致的遮挡目标；不得A计入四设施图集而B不计，或B包含真实设施深度而A只画图标。若B统一空间，完整计入其设施绘制、视口与遮挡成本；保持设施身份与稳定控制区的操作映射，不增加建筑点击。旧视频无已领取设施，不能替代这一项。
5. **采样。** 测试不适用限帧模式：同条件性能对比关闭引擎帧帽和VSync，并核对驱动/系统未另设帧帽；记录实际VSync、驱动限制和显示同步状态，不能只写两边设置相同。shader/纹理预热后在同一机器交错A/B/B/A，每段例如热身10秒、记录30秒。分别记录不含人为帧等待的实际忙帧、脚本CPU、渲染CPU、GPU耗时，以及整窗帧间隔中位数/p95；同步等待与忙时不得混为一项，不用帧帽或只读FPS掩盖成本。完整draw/primitive统计、纹理/目标缓冲内存、峰值和冷启动另列；GPU功耗只有可靠硬件遥测时才报，否则未测。若VSync/驱动限制无法实际解除，如实记为条件未满足，不能把受限结果当本次不限帧比较。几何帧序列另覆盖接缝/极区、云地相对位移、明暗边界、设施从背面进入正面；图像序列按相同相位比较，不把不同画面复杂度当方案差异。
6. **计量边界。** Visual Profiler的CPU部分只覆盖渲染，不含脚本/物理；与标准Profiler分开记录：[官方调试器说明](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html)。viewport计时需实际可用并覆盖所有绘制视口与setup；未启用时的0不当“零成本”。RenderingServer部分统计只计3D，不能直接拿其draw数比较A/B：[官方RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)。Compatibility后端若工具缺GPU/2D统计，用双方相同且受支持的GPU捕获方法；没有有效读数就保留未测，不悄悄切成Vulkan换题。
7. **判定。** 先要求两者达到相同可见质量/状态表达，再比较整窗增量及稳定性；若结果差异落在交错波动内，就报告无显著可判差异，不编造节省百分比。云端llvmpipe仅能帮助验证图像/源码链，不外推用户GPU。只读静态分析不能证明任一方案可上线或V7通过。

## 6. 给根线程的下一步方向

保留的观看目标是大陆连续绕入/绕出且球缘压缩、云层差速、固定光照/明暗体积、探索机运动与设施前后归属；让整个模块空间承托这些过程。相机绕转、真实云高度和统一设施深度仍是评估B额外价值的条件，不预选路线。早期[P2方向](next-image-direction.md)保留为过程记录，用户新确定的地表/轨道、独立操作及信息收纳以[M7](../../game-design/art/modules/planet.md)为准，当前构图见[P4](../planet-watch-management-v4/README.md)。各轮图像均不是运行底图，正式UI及测量仍未启动。

现有阻塞不是权限拒绝：尚无同条件B实现及用户目标GPU数据，CPU/GPU/能耗未测；当前图稿方向已被否定，正式UI仍待用户新图稿确认。没有自动审批拒绝、没有绕过动作。
