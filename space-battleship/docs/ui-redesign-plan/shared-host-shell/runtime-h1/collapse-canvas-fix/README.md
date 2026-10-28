# 收起快照：实际画布变换与截图像素修复

代码`design/shared-host-shell@ef409d5ca5216b9895cc45e6bd42e5d0bc2927bd`，待原Astra复核，未合main。根端确认原预览生命周期、焦点门禁两项关闭；本次只处理其后指出的canvas_items拉伸下截图裁切P2，不重跑已关闭项或扩大DPI矩阵。

## 修正

之前main把逻辑Rect2i(0,65,808,835)直接当截图像素裁切。现在main只交实际根Viewport图像给shared_host，由实际静态显示区域Control的`get_viewport_transform() * get_global_transform()`将本地矩形投影到截图像素。前者包含画布到embedder的拉伸，区别于仍为逻辑坐标的global-with-canvas；依据[Godot CanvasItem变换说明](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-get-viewport-transform)，并在本地固定4.7.2实际量得0.8变换。

对投影矩形向外取整，和图像边界求交；部分越界先按原请求矩形补齐不可取得的区域，再归一到显示区808×835，避免把交集直接拉满而改变内容位置。向外取整最多有边缘像素舍入，不改布局或战场逻辑投影。空图、空矩形或完全越界返回失败，main保留当前模块显示，不进入空白收起态。静态纹理仍只捕获一次。

## 一个实际非1440窗口的必要证据

正式main、真实Session/native、Godot4.7.2，在原任务中实际把窗口改为1152×720（仍16:10）。根图像实测1152×720，逻辑visible_rect仍1440×900。显示区域本地808×835，实际变换为X/Y 0.8、原点(0,52)，投影像素矩形(0,52)/646.4×668；取整请求647×668，最终纹理808×835。

[收起前1152×720](evidence/equipment-before-1152x720.png) · [收起1152×720](evidence/equipment-collapsed-1152x720.png) · [恢复1152×720](evidence/equipment-restored-1152x720.png) · [实际归一快照808×835](evidence/normalized-snapshot-808x835.png)。收起与恢复两图均已实际查看：静态背景未裁入公共导航或右战场，恢复为同一模块。

[6项必要记录](evidence/observations.json)全部通过：实际窗口/图像尺寸、空帧保留显示、部分越界补齐再归一、该窗口实际收起、静态纹理与模块绘制停止、实际恢复。部分越界检查只把同一真实帧取320×240作为边界输入，检查归一尺寸与补齐角像素；它不是另一个窗口或DPI场景。按钮信号驱动既有收起/恢复路径，没有手工拼装整屏。

[解析检查](evidence/godot-check.txt)和[实际日志](evidence/godot-live.txt)通过，无脚本/资源错误，仅既有Xorg VSync警告；Git diff检查通过。[环境与哈希](evidence/environment.json)。预览/焦点已关闭函数体逐字节保持cf31afd8，模块、模型、贴图、保存/战斗业务均未改。本轮没有全链或全DPI通过结论。

当前无权限/运行阻塞，交原Astra复核本尺寸裁切P2。
