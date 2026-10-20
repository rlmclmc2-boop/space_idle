> 本版因主体过黑被用户否决。继续稿：[09同尺寸明度对比](../cannon-value-review-09/normal-comparison.png) / [09说明](../cannon-value-review-09/README.md)。保留原覆盖尺寸，仅修正顶面明度，未接入。

# 炮机内部表达简化 08 · 仅设计稿

本轮沿用07外承载面95%目标、逐底座舰体边界限幅后已确定的24个显示尺寸，保留06轮廓与短炮管比例，只简化内部表达。没有重新量尺寸或通过放大改变对比。

1. [同一07尺寸的正常窗口前后对比](normal-comparison.png)：原06内部 / 本轮简化内部，指挥BOSS、反应精英、锚定精英并排。
2. [同尺寸正向与转向](direction-check.png)：三舰各-35/0/+35度。
3. [正常窗口八舰、转向，再附细节](design-board.png)：细节放在正常比例检查之后。

对应HTML为normal-comparison.html、direction-check.html和review.html；请以100%查看。均为静态设计示意，非游戏截图。

## 本轮改动

中央深色炮机的多个小矩形、重复内框和亮边合并成连续的大暗面；用少量灰色侧面和顶部短肩面表现凸起高度。两侧连接件去掉重复银色条带，保留实体耳轴与侧面。白侧护甲保留清晰大白面/冷灰下侧面，后连接桥去掉小窗和多重嵌框。炮机仍在白侧甲之间凸起，未用顶盖覆盖，也没有变成平顶盖板。炮管与炮口尺寸未另行放大。

源图cannon-design.png由imagegen编辑06源图，只要求内部面/线简化。完整请求design-request.json，原始生成文件保留在/workspace/generated_images/exec-e02897ad-3c6d-4ee7-b52c-79f8b779b9b3.png。与06同为1230×1278 RGBA画布，不透明alpha轮廓IoU约99.63%；机械轴心、炮壳宽、短炮管比例元数据直接沿用06，不做新的轮廓设计。

## 固定显示基准与检查

build_review.py直接读取07/coverage-measurements.json中已选95%目标且经边界限幅的每个width_screen，不重新用最小凹槽×系数计算。新旧图显示尺寸逐底座完全相同，仍约18.5–24.6屏幕像素。07的部分锚定精英/反应BOSS底座限幅及同舰尺寸差异保持，不在本轮处理。

内部自查先看正常窗口八舰和0/±35度：中央暗机、白侧甲与短炮口分别保留，细亮框减少；再看放大细节确认侧面亮部与耳轴/承载高低没有被抹平。此为内部自查，外观仍待父审，不代表用户验收。

check_design.py重新将新图主连通体全部alpha>230像素，按固定07尺寸/原24轴心映射到原舰体。0/±35/±55度共120探针，越界0；含完整炮管的任意转向外接圆最小间隙约10px，不互叠。07尺寸/承载测量/限幅文件和06原PNG逐字节冻结。相对3bed1e2e，生产assets/data/scripts/config_excel、既有QA、导入器及测试均未修改。三个设计板图片引用完整、device scale1导出，结果见design-check.json。

未启动Godot、未接入、未合main，无执行阻塞，等待父审。

复现：python build_review.py；python render_review.py；python check_design.py。仅浏览器静态叠放PNG；临时本地服务仅绑定127.0.0.1且导出后关闭。没有程序重画贴图或修改生产资源。
