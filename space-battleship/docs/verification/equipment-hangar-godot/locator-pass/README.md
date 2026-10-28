# 装备选中关联可见性候选

固定源码 **b93597a33cf45d164b46edf38b48928440521ad7**，原目录/实现分支不变，未合main。承接根审对7a7d/eb8c的Frigate舰首错觉及Heavy防3长隐藏连接反例；原证据完整保留。本批只改装备呈现与现有M2定位要求，无main/业务/config/正式舰体、武器、碰撞或炮口修改，未自判视觉通过。

先看同版图：

- [真实新局Frigate：绕舰侧并定位中段炮塔](candidate/01-starter.png)、[全装备开放的小舰定位](candidate/31-frigate-full-equipment-dormant-slots.png)。
- [Heavy武器1](candidate/32-heavy-selected-weapon-0.png)、[武器2](candidate/32-heavy-selected-weapon-1.png)、[武器3](candidate/32-heavy-selected-weapon-2.png)、[武器4长舰炮](candidate/32-heavy-selected-weapon-3.png)、[武器5](candidate/32-heavy-selected-weapon-4.png)。
- [Heavy防御1](candidate/32-heavy-selected-defence-0.png)、[防御2](candidate/32-heavy-selected-defence-1.png)、[防御3邻近代理](candidate/32-heavy-selected-defence-2.png)。
- [Destroyer左右槽](candidate/30-destroyer-paired-mounts.png)、[部分解锁](candidate/25-partial-unlock-frigate.png)、[长MAX及完整费用](candidate/19-long-max-multi-resource.png)。

以上均真实Godot 4.7.2根视口1440×900原像素，未裁切、缩放、拼接。[原始操作](candidate/operations.json)、[四项保护回归](regression/runtime.json)、驱动和日志及所有文件hash见 [manifest.json](manifest.json)。

## 定位修法

选中槽在舰体/武器之后绘制前景定位线、目标框与简短同槽号标记。武器目标是实际正式PNG可见alpha包围轮廓（初始化每纹理只读一次get_used_rect并缓存），不是仅在数值anchor画点；“武1”等对应卡上的武器槽序号。定位端点避开其他终端矩形；只绘一个当前选中目标，避免全部连线一起遮住主体。Frigate原直杆取消，机械支承绕右舰侧，前景定位线连续指到中段实际炮塔，舰首不再形成连接终点错觉。

Heavy防3代理图标从船尾中央移至右上终端邻近维护空白区(495,243)，短支承/选中短虚线完整可见，不再依靠跨船体的隐藏长段。防御以虚线/虚框及“防3”等区别武器实体角标：**它是UI代理图标，没有对应的原生武器挂点，未给防御捏造native部件几何**。原正式武器锚点和所有者数据不改。

选中ID进入原有scene_picture失效签名，合并到既有可见帧刷新；只有选中/装配/舰型变化才需重绘场景。目标框用静态字体、纹理和预建StyleBox，无逐帧alpha扫描/样式重建，无新领域读取。Heavy8卡各实际点击一次，每次恰1条scene_redraw_request，comparison当前装备仍与该所有者slot一致。初始选择、换船及空槽也经真实画面覆盖。

## 同版验证与保持项

`EQUIPMENT_CAPTURE_COMPLETE failures=0 records=35`，沿原操作追加8张Heavy逐槽定位图。记录包含实际业务、状态及布局，不是35笔交易。新局/cleared1部分装备开放/全装备开放、Heavy新增空槽真实GUI直接安装、8卡选择映射、Destroyer左右对与缩小Frigate6休眠槽均保持。武器和防御+1/+10/MAX、Amount钱包减actual spent和等级count、候选不安装、实际换装冷却拒绝/到期、批量部分成交/遮挡/关闭重开、资源不足原所有者拒绝均0失败。报价/支付/回执由既有所有者，不使用UI业务算法或假响应。

`REVIEW_RUNTIME_COMPLETE failures=0`。原未知/拒绝/未提交/缺明细呈现语义、经济位置通知不重读槽/选项/比较/MAX、免费武器/防御实际分配的比较依赖与deferred合并、0.9375等比投影下两侧实际拾取全部保持，原始窗口/计数在runtime.json。活战斗和真实时钟仍推进，未以暂停业务换取0读取；边界回执输入仅证明实际Control呈现，不伪造native故障/财务执行。台面层次、安装留白、400/600字体、完整费用及移除常驻卸下也保持，底层合法空槽规则不变。

两个正式runner均在固定源码后以各自全新/tmp设置/存档目录启动并断言无recovery。首次新局没有造进度；后续部分/全开放及特定等级/钱包为明确的受控restore+实际native refit，不冒充自然赚取进度或个人存档。环境复用原 [environment.md](../environment.md)，无新工作区或重搭环境。预览在本地preview保留，不作正式同版证据；历史失败与原证据均未删除覆盖。

仍交原双审的视觉边界：非选中机械支承可被舰体遮挡；个别真实长武器轮廓角可能受邻近终端/其他正式装备覆盖，不能将数值或包围框正确当作全视角可读。所列实图应判断选中定位是否足够清楚，特别是长舰炮与防御代理。未扩Battleship四炮、全姿态/长值、完整键盘、Windows/DPI或长期性能；不代表全V0/V2/整体游戏通过。无环境/审批阻塞，执行者未实际上下文压缩；固定候选后不自行启动新批。
