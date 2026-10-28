# 中央反应堆静态体与局部工作层

用户已认可59dd464d中央核心/四向短接并授权真实Godot制作。本目录为新分层生产资源，不是把带字设计图铺成游戏页面。`static-bodies.png`为image_gen.imagegen原生透明图集（1536×1024），五个独立静态设备，未裁切或后处理。R1分离主体，R2扩大核心透明孔径，R3仅为四设备加入朝内的可见输入口；精确提示词及原输出路径/哈希见本目录文件。源输出保留于生成目录。

核心球、武器场、盾面、冶炼过程和凝聚变化由`working_fields.gdshader`分别绘制，不使用内建TIME；显式phase由显示层读取宿主模拟时钟推进，power只取已接纳负载。图中少量青色/琥珀属于静态材质识别，不作为持续工作/进度。零负载/暂停/隐藏仍须由同版真实运行证明。

源图完整尺寸、alpha可见边界、区域和未验收项见`manifest.json`，保持draft。`mounting-plate.png`和`mounting-plate-three.png`分别是四设备共用安装面及右下封闭服务口的原生不透明生成资产，原件保留于`/workspace/generated_images/exec-c067f060-c42f-4f4b-b977-6355e88f2e62.png`和`exec-c9d19e58-760b-475d-8b69-495f44825858.png`；两张均为1024×1536，无字无独立设备。唯一端口数值及最终变换在`src/ui/reactor_stage.gd::SOURCE_PORTS/_centre/_ports`，不复制到后端。模组位置由核心端口、轴向、短连接长度与模组输入口反推；等比缩放同时作用于实体/输入/效果。安装面提供埋入式主体通路，各设备输入端加短实体套管与端面；未开放支路使用封闭底板并封盖核心端口。实际近景品质及设计审查仍待独立复核。

用户标记原图`a8a214a4:docs/ui-redesign-plan/reactor-image-design/references/user-marked-upper-connections.png`已实际查看，上两路为优先核对项，四路均要核朝向、中心、插入及遮挡。新场景不改战斗几何、Amount、分配/支付计算或装备页。导入与舞台取证尚在推进，资产存在不等于V3通过。
