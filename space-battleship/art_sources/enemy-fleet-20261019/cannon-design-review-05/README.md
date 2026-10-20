> 本版父审不通过。继续稿：[06正常比例对比](../cannon-design-review-06/normal-comparison.png) / [06原稿结构说明](../cannon-design-review-06/README.md)。仅设计，未接入。

# 方向性装甲炮塔设计 05 · 仅设计稿

c58921f0在父审中被否决，未交用户验收：主体像圆形舱盖，转向不易分辨。本轮用前后不对称结构恢复炮塔识别，不继续加宽成圆饼，也不退回细长小战舰或长粗杆。

**先看[同尺寸正向与转向](direction-check.png)**：指挥BOSS、反应精英分别将-35/0/+35度放在一起，未放大舰体。再看[与04的正常尺寸对比](normal-comparison.png)，以及[八版整舰、转向和细节板](design-board.png)。相应HTML为direction-check.html、normal-comparison.html和review.html；请用100%查看。所有图片均为静态设计示意，非实机截图。

主体是近方形的厚装甲炮塔，前缘收束且平直，后部是宽厚的深色设备舱；连续浅色前甲与深色后舱形成方向性，不围绕中央深色面板形成白环。短炮管从前缘露出，有独立炮口；主要轮廓和体量仍由装甲主体承担。配色、斜面白甲和酒红机械层沿用15a102ac审美语言，不添加静态圆盘或基础底座。

内部筛选先看正常尺寸并排方向图，再看与圆盖04对比及八版：正向能看到收束前甲/短炮口与横向暗后舱；±35度时主体的斜边、前部和后舱一同转动，而非只转动中央一点。源图前甲/后舱RGB中值约230/226/221与36/24/28，明暗不呈前后对称。此为内部视觉自查，不代替父审或用户验收。

主体在设计板上按暗凹槽宽的120%摆放，约15.7–18.9屏幕像素宽；外露炮管约4.2–5.0像素长、约1.7–2.1像素宽，仅占整体长度约五分之一。尺寸为设计排版估测，沿用已有main.tscn体量（约0.7屏幕像素/逻辑像素），不写入生产接口。原24轴心与舰体PNG直接引用不变。

源图cannon-design.png，完整请求design-request.json。原imagegen文件仍保留在/workspace/generated_images/exec-012c3567-f446-4d65-a6b5-ecd4135cad9f.png。design-meta.json仅供静态设计板排版。

检查见design-check.json：相对c58921f0，8舰体PNG逐字节冻结，生产assets/data/scripts/config_excel、既有QA、导入器和测试均未变；三个浏览器设计板的图片引用完整，device scale1导出。未启动Godot，未接入、未合main，无执行阻塞，待父审。

复现：python build_review.py；python render_review.py。仅在临时127.0.0.1服务中用浏览器图片元素叠放原舰体/新炮身，结束即关闭，不修改原图像素或生产文件。
