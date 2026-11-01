# B01反应堆制作交接

目标见[M3](../../../../game-design/art/modules/reactor.md)，安装见[资产接口](../../../../game-design/art/modules/reactor-asset-contract.md)。

## 当前现场

分支`implement/reactor-centered-godot`。用户认可24db2a9c共同分面方向，非实机终验。公共材质精确消费9034af81，plate.state保留；未改Owner、装备、舰船、main或共享导航。本线程本人制作，不使用子智能体。

已用本地Blender生成独立GLB：舱室、核心、四设备、同源空心接头/管腔及1–4路机台。`generate_faceted_reactor.py -- --export-glb`输出`faceted-reactor.glb`和`faceted-layout.json`；端口读取`reactor_ports.json`，位置/轴向/插入深度一致。源1187×1326等比放入808×835，背景独立覆盖。渲染资产只用持续免费本地工具。

`reactor_scene.gd`已替换旧两栏控件布局：总控/均分带、完整分配行、底部等级/费用/数量/升级带。按钮预算和玻璃内区一起确定；比例在轨内，并随把手避让；沿公共字体/按钮/数字角色。已有实屏和原生拖动、×10/MAX成交扣费记录，当前仍需按最终渲染版重新绑定证据，不能拿中途图作最终交付。

## 当前具体一步

实时三维试作存在严重软件渲染开销，未通过性能。固定战场的诊断显示冻结写入仍慢，UI无重读/节点增长，三维整屏MSAA/绘制是主要成本。现在将同一GLB工作几何投影到Canvas：保留顶点法线、UV及16位深度，与三维机壳深度比较遮挡；静态材质/真实阴影仍由2×MSAA离屏绘制，只在设备范围变化时缓存。不是恢复旧整图/水波方案，也没有将关闭特效或降低刷新作为成品优化。

正核对`faceted-depth.gdshader`及`faceted-canvas-work.gdshader`的兼容渲染器编码/正面关系，修工作层压机件。当前运行检查日志`/tmp/reactor-faceted-depth-check.log`，图`/tmp/reactor-faceted-native-4-active.png`。在目视和深度探针通过前不可声称端接/效果通过。旧实时三维参考代码保全于/tmp/reactor-spatial-reference.gd，诊断日志在/tmp/reactor-faceted-*-profile*.log；未作为当前性能结论发布。

下一步：闭合遮挡后继续核心体积/汇聚释放和四设备工作过程的整体判断；完成同版1/2/3/4显示、原生操作、正常速度连续片与当前性能报告，再独立Git归档。上次已对用户报告的31.29→32.33、31.61→32.23属于旧软件ABAB；本轮架构/场景变化，不能拼接比较或声称目标硬件已通过。暂无权限阻塞，不等待用户。
