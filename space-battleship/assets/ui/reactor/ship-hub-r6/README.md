# 嵌入式反应堆舱室候选

`installed-bay-four.png` 由 R4 `background-four.png` 编辑生成，装备 `equipment-normal.png` 仅供暖象牙与深青材质参考。图像为四个较宽的舱壁凹入工作口与整宽前沿工作台；原小口和悬浮金铜仪表不再同时呈现。`installed_work.gdshader` 与 `installed_pulse.gdshader` 是嵌入口适配的工作光，保留 R5 旧版证据对应的 shader 不变。Godot 将它绘制到 808×835 内容区，运行状态、名称、倍率、比例、工作动画和交互仍由界面代码根据 Owner 实际状态绘制。第三、第四模块尚未开放时，未开放工作口不显示状态和控件。

R7 在两个嵌入口 shader 中加入下方斜玻璃 UV 遮罩和零负载全透明工作层；运行态分别绘制武器导流、盾场网格、冶炼热栅、凝聚收束。
