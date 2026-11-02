# 玻璃环境反射与透光制作检查点

生产源由manifest/source-closure记录；替换范围见installation.json，全部20份私有运行源按source-closure.json分块顺序还原核SHA。不覆盖公共宿主、装备、Owner或玩法。

核心玻璃提高曲面分段与轴向深度；武器与凝聚玻璃替换原表面为封闭半壳，带内外壁、端环和切边。glass_materials统一厚度/镀膜反射率/吸收参数；同一实际曲面计算宽面天空/地面、主光和两盏现有舱顶灯的近似反射、薄壳透过。非场景光线追踪/屏幕折射，不复制屏幕、增加玻璃叠层或新增灯。反射在顶点计算，片元插值；与金属共用遮挡深度。保留内部各自工作过程。

four/single/two/three的zero/active原屏及<1MiB JPEG；four/single各12秒正常时间影片、全时段0.25秒联系图及2/4/8秒原帧；four-mixed-low为受控武器/炼铁各1%、盾甲/凝聚真零；原生轨道/均分/暂停恢复、静态玻璃参数、同源两灯和几何日志。开放/钱包及少模块均为受控，不冒称自然流程。低载分配经真实Owner计划，不冒称人工拖至1%。

GLASS_FIXED_STATE中的phase/load/formation为未写入的null，表示未设覆盖值而非GPU默认值为null；源码确认玻璃不消费这些时间/负载字段。厚度/反射参数真实读回，内部工作phase继续增长。各影片probe与完整帧时间戳另存，采集25fps不等游戏FPS。X11 fallback需以完整解码结果为准。

冷态前后图绑定12cec026/e95549c2旧证据与本源，批准图并置保持整页对照。作者判断见author-review.md；性能口径见performance.md。无本版独立审核/用户/全任务通过。
