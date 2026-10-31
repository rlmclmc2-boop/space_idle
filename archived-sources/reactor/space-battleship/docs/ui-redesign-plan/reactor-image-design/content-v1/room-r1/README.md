# 反应炉同空间舱室 R1（整体感受候选，待用户确认）

用户认可[`bd136fd2`前景视觉](../README.md)与[`44fb4ece`舱室想法](../background-r1/README.md)，但指出前景仍像贴在房间图上。本轮按[`4f4d63d5`固定作图范围](https://github.com/rlmclmc2-boop/space_idle/blob/4f4d63d57ddc215453993cce739eaa3eecfc4198/space-battleship/docs/ui-redesign-plan/shared-host-shell/reactor-drawing-v1/README.md)，将核心、四角模块、短接和舱室重组为同一透视空间。后舱左右两机安装于壁龛，前方左右两机落在地座；核心有中央支承，四条短桥在相同透视和遮挡关系中接入机器。奶油白壳、深青后舱和局部青/琥珀工作体延续已认可的造型身份，舱室结构减去前版密集小机械。**当前审整体构图与空间关系；不是已批准的运行UI或Godot画面。**

| 状态 | imagegen原图 | 固定宿主整屏配合图 |
|---|---|---|
| 四设备 | [同空间原图](reactor-four-raw.png) | [1440×900整屏](reactor-four-host-layout.png) |
| 三设备 | [同空间原图](reactor-three-raw.png) | [1440×900整屏](reactor-three-host-layout.png) |

四设备原图为imagegen编辑`44fb4ece`四设备舱室与`bd136fd2`四设备前景后的原生输出`/workspace/generated_images/exec-46dec92f-7668-4cd6-93c5-55dcf4429299.png`，1233×1276，SHA256 `09a3dd7717a56142d048fe7cc8ba3f83949d4a04d6c7a766fd23fdb61bbe1156`。三设备原图由该四设备稿编辑，去掉右下凝聚机器、读控及短接，最后消除地面空站轮廓；原生输出`exec-9d281a33-6ead-49b4-9c67-3c79516faaac.png`，1233×1276，SHA256 `8e2c5782638583da6b9bd88bdd7a6d10c80588f800dd9cef199c2474c4ce527f`。两张原图未裁切、拼贴或后加字；未列入候选的中间稿只作内部自查，不代表用户认可。

整屏配合图由[`compose-host.sh`](compose-host.sh)把原图按宽808等比缩放、居中裁少量纯环境至内容808×835，再置于固定宿主(0,65)。[`shared-host-reference.png`](shared-host-reference.png)是整体组范围图的未改副本。两张配合图对模板的顶部公共65px及右战场632px逐像素差异均为0；这是**模板合成的静态审图件**，不是原生imagegen整屏或真实Godot截图。主控和四路读控仍有基本占位，数值、18/16px文字、长金额、失败反馈和实际滑杆命中区尚未按新透视测量，必须在整体空间方向获认可后细化，并重新达到原[布局预算](../layout-review.json)要求；不能据此声称176×112/776×144已验收。

实看限制：四设备稿的舱壁安装、地座、核心支承及短接已形成统一空间；三设备版右下是连续舱面，没有第四设备或空锁卡。读控面仍较相似，部分模块壳体与舱壁的真实接触细节、明暗主次及三设备右下空场平衡需原独审/用户判断。原图仍烘焙了占位滑杆、按钮和工作光，不能直接导入为可交互/可按负载暂停的分层资产。**用户确认整体空间后才恢复实机细节处理；不改`main.gd`，不合main，不称V3通过。**
