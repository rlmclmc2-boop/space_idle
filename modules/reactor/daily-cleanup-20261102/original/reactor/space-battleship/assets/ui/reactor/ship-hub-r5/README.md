# R5 反应炉工作仪表

四张透明 RGBA 仪表原图保持各自 1557/1558×1010 分辨率，Godot 以 216×140 消费。四件的壳体、滑杆槽和下沿小读窗同源；武器用琥珀能量管、盾甲用蓝色蜂窝屏、炼铁用竖向热栅、碎片用晶体凝聚腔区别工作。图像由 ImageGen 从 `ship-hub-r4/weapons-control-3d.png` 的透明图编辑成武器首件，再以首件为壳体参考生成其余三件；本目录保留生成原图，未将源图压成低清贴片。`central-console-workbench.png` 以原中央控制台轮廓及新仪表材质为参考，提供暖象牙信息面与深青按钮承托，仍由 Godot 绘制全部实际状态与文本。

游戏时 `reactor_scene.gd` 将上槽比例和下沿名称/倍率绘制在资产之上；`instrument_work.gdshader` 按 Owner 已接纳 load 压低停机工作腔，`instrument_pulse.gdshader` 在运行时间内给四种腔体独立节奏。`ambient_work.gdshader` 由核心实际 load 给相邻舱壁和四条短接少量受光。金属/玻璃静态层在停机时仍保留。
