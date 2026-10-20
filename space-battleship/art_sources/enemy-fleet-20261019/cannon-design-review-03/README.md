# 炮身设计审阅 03 · 未接入

45fe11a2因外观被否决。本轮遵照补充方向：炮塔主体承担主要造型，外露炮管缩短并收细，不再用粗长炮管表达朝向。当前仅交设计稿，等待用户确认；不替换runtime，不接入游戏，不合main。

[设计板PNG](design-board.png) / [可按100%查看的HTML](review.html) / [独立炮身细节原图](cannon-design.png)。设计板同时展示放大细节、八版原舰体正常窗口体量和指挥BOSS的±35度转向。所有舰体和固定底座直接引用现有PNG，炮图用浏览器图片元素按原24个底座坐标叠放，没有重画或修改舰体像素。所有装配图均是静态设计示意，非游戏截图。

造型依据为15a102ac原设计稿：冷灰斜面白装甲、酒红机械内层、克制琥珀指示和深色机械炮口。紧凑楔形炮塔主体以分层装甲肩和中央灰甲形成主造型。源图估测：炮管宽约为炮壳宽的11%，外露长度约为炮壳长度的27%；炮管作为附属结构，主体承担绝大部分面积。此比例记录是设计排版说明，不是生产配置。

正常比例示意沿用上一轮main.tscn记录的舰体体量，以约0.7屏幕像素/逻辑像素排版，炮壳按暗凹槽宽的100%摆放，约13.1–15.7屏幕像素；详细尺寸见design-meta.json和review-measurements.json。这些尺寸只服务设计板，不写入游戏接口。浏览器和图片查看器请使用100%查看；网页不会自动放大舰体。

cannon-design.png为本次短细炮管送审图，完整请求design-request.json。study-01/02仅为生成过程参考，非送审方案，也不由任何运行脚本消费。原始imagegen输出仍保留在/workspace/generated_images：最终exec-955b4ade-14d8-4dac-bb10-d90494be0f6a.png；参考exec-ea382aac-dac2-489e-82da-3ff85e65b65b.png与exec-e0245e34-ac12-4661-838d-10eb6d2bd698.png。

检查：设计板图片引用完整并以device scale1导出；与45fe11a2比较，生产assets/data/scripts/config_excel、既有dev/qa、导入器和测试均未改，8舰体PNG逐字节一致。见design-check.json。本轮没有启动Godot，没有声称动态接入/战斗或旋转结算验收。无执行阻塞，下一步仅等用户确认外观。

复现设计板：python build_review.py生成HTML；python render_review.py通过仅绑定127.0.0.1的临时本地服务以Chromium导出PNG，结束即关闭服务。脚本只读取PNG/元数据并排版图片，不修改图像像素或生产资源。
