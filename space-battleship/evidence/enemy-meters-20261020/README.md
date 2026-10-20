# 八舰血盾条居中与边缘修复

基准main c45f46c4。只改 battlefield.gd 的八舰血盾条横向布局和 retained_enemy_contacts.gd 对应调用；沿用既有条宽/舰体fit/父级缩放，排除旧outer-wing外移规则。非八舰legacy样式与标题位置保留。舰体资产、显示尺寸、编队坐标、geometry_texture、战斗判定和所有数值配置不变。

根因：两条绘制路径都按实际静态舰体尺寸得到条宽，却对explicit_formation外侧舰把left设为舰体中心（右侧）或中心减整条宽（左侧），然后clamp整条位置。右上anchor舰体中心x506，原条中心522.6543，向右偏16.6543；scout偏25.2677，reactive偏16.6806。父级缩放不是根因。固定八舰画面里旧条端点仍在clip内，贴边/截断观感来自外移后clamp；没有将该画面描述成GPU真正裁掉像素。

修复：八舰横向以舰体中心对称，近边缘时根据中心到[6,566]安全边界的距离对称收短，而不是整条挪离舰体。retained/canonical使用同一个span；ratio仍表示原血量/盾量比例。外圈、舰体和炮台均未缩放或移动。

证据：before.png / after.png 为同一实际main.tscn八舰夹具、同一1372×883默认窗口的原始截图；before-large.png / after-large.png为1952×1256实际窗口。第一排scout/sentry/interceptor/swarm/anchor；第二排reactive/shielded/command。保存关闭、QA保持血量、实际交火后暂停清理瞬时弹道/浮字；固定fx_time及关闭shake用于同画面对照，没有裁剪、标注或拼图。before/after JSON内八舰全部rows（含位置、宽度、旋转后显示包围框）完全相等。血盾条中心误差8舰均为0，96项检查0失败。

新增断言：实际retained血盾节点相对舰体居中；get_global_transform_with_canvas后的完整矩形落在实际battle_clip内；canonical与retained横向一致；测试左右x20/x552并叠加±9逻辑单位shake（实际中心x11/20/29/543/552/561），两端始终在[6,566]内，继续居中。保留原有alpha中心、单格显示尺寸、六档fallback、native view尺寸检查。Linux Godot4.6.3 llvmpipe/GDS；没有声称native整场/性能验收。未改攻击或共享效果，不跑无关组合/全量测试。

复现：隔离项目图形模式运行test/test_enemy_base_eight_battle.gd，ENEMY_BASE_OUTPUT指向test/work本次目录；旧c45f46c4原版两脚本搭配ENEMY_METERS_BASELINE=1只记录旧偏移，正常修复版本不设此flag。产物before/after.log及summary.json。独立分支父审后处理，未合main，无执行阻塞。
