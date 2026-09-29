# 反应炉模块化美术

当前布局接口见 [interface-contract.md](interface-contract.md)，不在本文件重复坐标。

复用：reactor-header.png 提供左上机械球腔；module-bay-frame.png 仅提供主管无分叉纹理；module-weapons-v2.png、module-smelting-v2.png 提供设备；weapon.svg、defence.svg、smelting.svg 提供模块图标。旧版资产保留，旧槽位 SVG 不再被此界面引用。

新增原生 SVG：integrated-console.svg 是统一升级台、能源控制台、主管和扩展接口；module-console.svg 是所有设备共用舱；allocation-console.svg 是所有分配行共用底板。沿用既有切角、深蓝玻璃、青色金属线框语言，文字和业务数值不烘焙在图片中。

新增 module-defence-v3.png：2026-09-28 经 imagegen 技能、内置 image_gen.imagegen 生成；源 exec-3611b03d-f288-4038-8d2f-54555b2ba486.png。提示词：单个紧凑盾发生器，透明背景，三分之四正面，黑色金属径向装甲、蓝色饰条和少量琥珀灯，中央留空暗孔，完整机体与安装脚；无文字、场景、UI、护盾或粒子。消费尺寸 180×180。中央蜂窝护盾由 Godot 局部动态层绘制。

能量球、主管流光、设备脉冲、能源滑杆和分段条由 reactor_visual.gd / orb.gdshader 负责。静态机体可复用既有自发光材质，运行特效保持独立。

新增 module-housing-v3.png：imagegen 生成共用机械舱框，源 exec-2486c2f2-ec28-4f62-8444-cf334f2d4ae5.png；提示词为 3:1 黑色金属切角舱、左侧 38% 空设备腔、右侧无文字暗玻璃、细青光与少量琥珀灯，无设备或控件。按 628×204 使用；module-rim.svg 叠加模块色灯带，module-console.svg 只提供原生细分隔线与能源槽。

module-coupling.svg 沿用原生 SVG 金属风格，提供通用穿舱法兰和实体支管；由绘制层叠加管内流光，设备压住管端。主管改用无分叉纹理片段，避免烘焙开口与模块位置错位。

room-backing.svg 替代整张旧通用舱铺底，只保留暗金属墙面与结构缝，避免旧空面板、横梁控件槽透出；底部装饰条已移除。核心出口与横管动效共用接口文档中的路径。

宝石凝聚复用 `assets/hightech/furnace-jewel-core.png`，裁取晶体主体后按 130×180 展示；来源见高科技资产说明。`condensation.svg` 沿用原生模块图标风格，供能与向心凝聚粒子由 Godot 绘制。

## 历史素材来源

来源：2026-09-28 使用内置 `image_gen.imagegen`。`reactor-room.png` 原件 `exec-d8f59902-53a7-4df9-9fed-d60691b79e38.png`；`reactor-header.png` 原件 `exec-6c534376-dbba-4de9-9e7c-d0b1f173c360.png`，提示词要求球腔留空、主管落在统一轴线、顶部与通用舱相接；`module-bay-frame.png` 原件 `exec-abcb1d5b-1215-4525-ac82-2fd1e6776161.png`，提示词要求连续主管、空安装腔、可接续机房结构。`footer-housing.png` 原件 `exec-de2858db-f4c1-4c4e-be57-f5666a3fab33.png`，由通用舱金属风格生成透明窄幅仪表外壳，按接口规范裁放。`module-weapons.png` 原件 `exec-8e3be609-ec5e-441a-addc-bd6864c52854.png`；`module-defence.png` 原件 `exec-e4c41a03-a7b0-442a-b5c6-f89c18478b18.png`；`module-smelting.png` 原件 `exec-c6144db5-454f-4581-bce4-c0b6f0939bfd.png`。三个展示件要求透明背景、独立机器、无场景与运行特效。三张槽位 SVG 直接按接口规范绘制。
