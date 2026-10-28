# R4 下两读数玻璃内区窄修

只调 `reactor_stage.gd` 中铁产出/碎片三行原生文字的安装坐标，不改资产、字号、滑杆/按钮、业务、核心或 `main.gd`。下两路三行调整到实际凹入玻璃面内，结束行离下内框约6px；碎片三行再向右避开左侧倒角。铁产出效果末尾仍留右边距。固定18px增益及16px手动/有效字号。

同一 Godot 4.7.2/native Session、1440×900 Xorg:99 版本三张整屏：[正常四路运行](active.png)、[鼠标25→1/0/1/0草稿](preview.png)、[整组确认后](applied.png)。草稿时核心仍按旧实际负载工作，[四路鼠标日志](four-mouse.log.txt)记录预览有效及确认成功；[驱动](four-mouse-driver.gd.txt)及[运行日志](states.log.txt)/[驱动](states-driver.gd.txt)留存。引导按公开路径先结束；开放与预算为测试驱动的公开 API 临时注入。顶部0..65仍是宿主旧导航，归整体组。
