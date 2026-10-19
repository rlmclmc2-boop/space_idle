# reactive-identity-20261019
基准3b853209。只重做reactive的舰体辨识，保留sentry和当前单格大小；三块装甲围小核心、结构空隙、无中央长船头、保留配色。编队重设计和外圈去留继续暂停，不合main。
完成：调用imagegen，以旧reactive与sentry作风格参考，生成三叶/Y式三装甲透明静态源。源图/提示/请求hash入art_sources/enemy-fleet-20261019/reactive-three-plates*，导入脚本用该图覆盖reactive atlas来源，alpha清理/等比缩放居中；没有程序重画舰体。
保留：sentry与其它6舰逐字节不变；生产scripts/data/config_excel/addons不变，geometry_texture/中心判定/防御数值不变。尺寸框仍114.4×133.333，体框90.4×79.333；同比两舰高度79.210与79.333，相差0.123逻辑，未拉伸或为了外圈缩船。新形状等比宽86.809对sentry90.4。
验证：原资产透明/比例/组件及geometry检查通过；reactive-compare实际2舰同比、ordinary-eight实际8舰场景共331检查0失败。默认窗口1372×883原始截图，保存基准8舰截图供前后核对。中心像素alpha253，显示中心检查通过。QA实际交火后暂停清理瞬时弹道/浮字；本地Godot4.6.3 Linux/GDS，不作正式native性能结论。
交付evidence/reactive-identity-20261019的同比、八舰图、前版图及检查结果。外圈没删除/扩大，显示布局与编队没改；源造型辨识效果由父/用户看图确认，当前任务无执行阻塞。
