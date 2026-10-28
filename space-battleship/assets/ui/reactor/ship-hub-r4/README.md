# R4 运行资产分层

background-four.png / background-three.png 是已批准 [R4 构图](../../../../docs/ui-redesign-plan/reactor-image-design/content-v1/ship-hub-style-r4/README.md)的无运行光、无文字、无按钮和滑杆静态舱室版。ImageGen 编辑原生输出分别为 exec-8f419dbd-cbe8-4804-aa51-7fc4dc7c2bfe.png 和 exec-be12b972-d289-4248-ad39-39f7cd922acd.png；统一按宽 808 等比缩放、居中裁纯环境至 808×835。三设备版的凝聚端口、支路、读控底座整套不存在。安装 SHA256 分别为 3fc653ca784734304f01c8c2ba08bdfe8f27de7655dc6f68671c5ad72c831db9 与 17f7f0f24e6d1775e0976c69e4910a62e6316fcbaea81f7616f816ddc9cd781d。

core-work.png 是已批准 R4 四设备原图仅球体内部的 264×264 工作纹理裁片（由 808×835 等比图的 (272,211,264,264) 取得），SHA256 eb016b27234fc2920fa1e5a4192da6c77a6b7c8a8bd7a16ab79f9891f73834e7。core_work.gdshader 将其限制于球内并按真实核心负载显隐、以游戏时钟扰动内流；hub_work.gdshader 只画四个接口窗口和短接的局部能量。零负载关闭对应工作层，暂停冻结相位，隐藏停 SubViewport 更新。核心效果仅覆盖 264×264 区域，避免整张画布逐帧采样。

四个滑杆、读数与整组主控由 src/ui/reactor_scene.gd 建立原生控件，静态图不提供可交互伪按钮。运行坐标以固定内容根 (0,65,808,835) 的本地左上为原点；本目录不含业务量、报价或游戏规则。
