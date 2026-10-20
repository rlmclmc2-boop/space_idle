> 本版显示比例暂不放行。当前仅用同一炮身做覆盖比例修正：[07正常窗口覆盖对照](../cannon-coverage-review-07/normal-comparison.png) / [07测量与边界说明](../cannon-coverage-review-07/README.md)。不生成新炮图，未接入。

# 原稿炮机结构设计 06 · 仅设计稿

05仍像白色盾形盖板，未通过父审。本轮重新以唯一认可原稿integrated-turret-bases-approved-20261020.png（15a102ac）为结构依据：白色侧护甲包住暴露的深色炮机，保留炮机高度、暗侧面与机械连接，只缩短外露炮管。没有用整块装甲顶盖覆盖炮机。

1. [先看正常尺寸前后对比](normal-comparison.png)：同一舰体/底座/显示体量，05盖板与06侧甲包炮机。
2. [八版、转向及原稿局部对照](design-board.png)：下方直接对照原稿指挥BOSS炮塔局部（含固定底座）与新独立旋转炮身细节。
3. [同尺寸-35/0/+35度](direction-check.png)：指挥BOSS、反应精英的正常窗口体量。

相应HTML为normal-comparison.html、review.html、direction-check.html；请以100%查看。以上都是静态设计拼装示意，非游戏截图。

内部检查先用正常比例：深色长方炮机与白色侧护甲各有形体，前缘短炮口单独突出；深色侧墙、上缘亮倒角和两侧横向耳轴/连接件表现机械高度，不靠细纹路装饰。首次生成的中央炮机偏窄，已继续拓宽，侧甲收拢；当前提交源图为cannon-design.png，study-01.png仅是未送审的过程参考。没有静态圆盘/新底座。

八版设计排版主体约15.7–18.9屏幕像素宽；中央深色炮机约4.7–5.7像素宽，含两侧连接件的机械跨度约8.6–10.4像素；外露炮管约3.0–3.6像素长、2.2–2.6像素宽。上述为按源图估测及现有main.tscn体量（约0.7屏幕像素/逻辑像素）的设计排版，不是游戏接口配置。装甲/炮机主要体量保留，只将外露炮管降为附属。

cannon-design.png为本轮候选，完整请求design-request.json；study-01-request.json记录原稿结构重建，随后refine请求拓宽深色炮机。原始生成文件仍保留：当前/workspace/generated_images/exec-31632af9-cb08-4273-bbf8-1faf60fdfa68.png；参考exec-df53587e-0c54-47b9-8ad2-24a27346ca38.png。原稿参考PNG未修改，局部只由浏览器图片裁视展示。

冻结检查见design-check.json：相对dca7001a，8舰体PNG逐字节相同，生产assets/data/scripts/config_excel、既有QA、导入器与测试均未改。三个浏览器设计板图片引用完整，device scale1导出；未启动Godot，未导入、未接入、未合main。无执行阻塞，待父审。内部自查不代替用户外观确认。

复现：python build_review.py；python render_review.py。仅使用浏览器图片元素静态叠放现有舰体和新图，按原24轴心旋转；本地临时服务仅绑定127.0.0.1并在导出后关闭，不改原PNG像素或生产资源。
