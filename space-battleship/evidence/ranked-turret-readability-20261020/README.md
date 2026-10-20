# 精英/BOSS炮台原尺寸辨识修复

基准6fe75f56。仅test_enemy_ranked_art.gd显式选择dev/qa/ranked_turret_preview.gd，生产scripts/data/assets/config_excel全部字节不变，1/2/4接口也不变。没有改变舰体、挂件、配装数量/伤害/冷却/倍率或编队。没有往静态舰体烘焙炮台。

旧炮身仅约2–4屏幕像素宽且棕灰贴近舰体。预览炮台改为更宽银灰炮身、黑色外轮廓、深蓝灰圆底座、铜金亮边和橙色识别点。放大的是实机炮台绘制轮廓；不是放大截图。保留现有独立炮台pivot/aim/muzzle，圆底座抵消原绘制port/face偏移后准确以live pivot居中，炮身前端仍在原炮口。精英retained和BOSS普通绘制共用同一预览外观；普通护航的能量炮绘制不变。炮台仍在舰体/挂件与防御层之上。

| 舰体 | 精英修复前→后（2武器） | BOSS修复前→后（4武器） |
|---|---|---|
| 锚定 | [前](before/anchor-elite.png) → [后](after/anchor-elite.png) | [前](before/anchor-boss.png) → [后](after/anchor-boss.png) |
| 反应 | [前](before/reactive-elite.png) → [后](after/reactive-elite.png) | [前](before/reactive-boss.png) → [后](after/reactive-boss.png) |
| 护盾 | [前](before/shielded-elite.png) → [后](after/shielded-elite.png) | [前](before/shielded-boss.png) → [后](after/shielded-boss.png) |
| 指挥 | [前](before/command-elite.png) → [后](after/command-elite.png) | [前](before/command-boss.png) → [后](after/command-boss.png) |

全部为1372×883原始实际主场景截图。before从6fe75f56逐字节保存；after为相同隔离夹具重新实机捕获，未裁切/缩放/拼图。敌舰body、display frame、血盾/名称、pivot和muzzle各字段逐项与基准完全一致；实际交火时序会使我方炮台姿态/资源显示细节不同。

700项专项检查0失败：精英2/BOSS4独立组件、底座原屏像素>=12（实测12.453–18.367）、挂点在不透明装甲上、底座两两不重叠、retained炮台层级在舰体/挂件/防御层上方；保留原有身份/只读接口、中心/几何/血盾留白、native view桥接检查。没有攻击逻辑或生产挂点变化，故未扩展武器效果组合/性能/全量测试。Linux Godot4.6.3 llvmpipe/GDS，不声称native整场或性能验收。

像素采用Viewport最终stretch乘CanvasItem变换，不能仅使用全局canvas scale=1。原引擎记录after.json中的window_png调用ViewportTexture.get_size得到965×621，而实际get_image保存的所有PNG解码均为1372×883（summary.json独立核对）；本次已把夹具该日志字段改为从get_image取尺寸。scale.log保留引擎返回值，700条断言的像素尺度使用正确的最终stretch0.702869。

复现：图形模式运行隔离test_enemy_ranked_art.gd，RANKED_OUTPUT指定test/work本次目录，默认启用新预览外观；RANKED_TURRET_BEFORE=1可保留原绘制进行观察，像素尺寸阈值用于新外观。生产不会加载这个QA外观。独立提交供父审，不合main；无执行阻塞。
