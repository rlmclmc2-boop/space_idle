# 下两玻璃首行净空窄修

基于 `e368f28e`，只修改 `reactor_stage.gd` 下两设备三行读数中的首行 y595→601；为保字形间距，手动行 y616→620；有效行保持 y637。18/16px字号、右下x642内边距、现有厚体资产/光路/滑杆/主控/业务/main均未改。实际1x截图放大比对：旧首行亮字约 y668–680，被玻璃上横线穿过；本版首行约 y674–686，手动约 y692–704，有效约 y709–721，三行上下均落在深色内区，底框与字形保留间隙。

同版 Godot 4.7.2/native Session、1440×900 Xorg:99：[四路正常运行](active.png)、[鼠标25→1/0/1/0草稿](preview.png)、[整组确认后](applied.png)。[四路鼠标日志](four-mouse.log.txt)记录四路变化、预览有效与确认成功；[驱动](four-mouse-driver.gd.txt)和[正常态日志](states.log.txt)/[驱动](states-driver.gd.txt)留存。临时开放与预算仍通过公开 Campaign/Economy API，仅为画面/交互核对；顶部公共导航由整体组接入。
