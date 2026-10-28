# 共享宿主三项P2修复候选

原Astra复核更新：预览生命周期与焦点门禁两项已关闭，1440×900收起显示改善；新增的非1440截图像素裁切问题经[画布变换窄修](../collapse-canvas-fix/README.md)，也已获原Astra限定关闭，无新增P1/P2。本页43项保留其原代码范围，不作为全DPI通过。

代码`design/shared-host-shell@c49ea0a7af6e86a25611e045e2311867b1772ed6`，基线72c113aa；原Sol中执行者/root在原工作区完成，待根端原Astra高复核，未合main。仅对应根端转交的预览生命周期、非文本焦点门禁、收起状态三项P2，没有重跑玩法/保存全链或接管模块美术。

## P2-1：导入/新游戏预览退出

之前把_pending_import/_pending_new_game当作持续输入独占，候选却没有取消或离页清理，导致返回装备后仍挡住战场。现在两者只是未提交的候选，不再产生模态输入所有权；设置有“取消新游戏预览”“取消导入预览”，并明确说明离开/收起设置会取消未确认预览。实际离页成功或收起时清理两候选及旧提示，原Session/存档不动，确认仍要求对应的有效预览。

原_preview_import/_apply_import/_preview_new_game/_confirm_new_game/_replace_session及重铸预览/确认/取消函数体逐字节保持基线；没有绕过确认、通过替换Session来解锁、调用取消后的提交或新增保存格式。实际重铸事务_pending_reforge仍保留原保护。

本组16项均通过：分别实际创建新游戏/导入候选，显式取消、离页和收起可清理；旧确认返回原PreviewRequired，Session实例及四个存档文件哈希保持，回装备的Space/G与右战场鼠标恢复。存档哈希比较发生在正常退出保存之前；候选不是伪造Dictionary，使用真实GameSession/native及真实存档包。

[新游戏取消控件](evidence/preview_lifecycle/new_game-cancel-control.png) · [导入取消控件](evidence/preview_lifecycle/import-cancel-control.png)。控件在设置原滚动区域内，未重做整页设置美术。

## P2-2：统一活动UI键盘焦点与战场撤焦

共同门禁改为检查根Viewport与战场SubViewport的所有可见焦点Control，覆盖Button、LineEdit、ItemList、HSlider等，不再只识别文本框。战场SubViewportContainer的自身焦点是游戏输入归属，予以排除；其内部真实按钮等控件仍算UI。Space/G的全局快捷入口共用此门禁，控件自己的正常GUI按键行为仍归控件。

无模态时，战场首个鼠标按下明确撤离两Viewport的UI焦点，消费该按下，不同时领取掉落；随后鼠标和快捷键恢复。真实弹层/重铸事务仍阻断，该点击不替用户取消模态。没有重复坐标逆变换或把首击转发两次。

本组21项均通过：实际取得焦点的数量Button、设置LineEdit、重铸ItemList、现有反应炉HSlider在无Popup时，门禁为真且Space/G不改变全局暂停/驻守；真实鼠标首击撤焦且不进入战场，下一击进入原逻辑视口，随后快捷键正向对照恢复。装备批量作为真实模态对照仍不能被战场点击关闭。控件设焦使用原生Control.grab_focus，输入通过生产Viewport事件路径，不是伪造焦点布尔值。

## P2-3：收起时保留静态环境与明确恢复

收起后仍保留当前导航选中态，在内容区显示一次性静态快照、暗化状态、“装备/星球已收起”和就地恢复按钮；更多中的恢复继续存在。快照在更多菜单实际退出的渲染帧后取得，避免把菜单残影冻结。原模块隐藏、原实例保留，恢复才显示当前状态；没有为背景继续跑被收起模块动画。

本组6项均通过，装备和星球各验证明确状态/选中、快照纹理字节不变且模块视觉停止、鼠标点击就地恢复同一实例。星球检查隐藏期间视觉phase不变，装备检查隐藏期间scene_draw计数不增；不是拿持续ViewportTexture充作静态图。

[装备收起](evidence/collapse_state/equipment-collapsed.png) · [装备恢复](evidence/collapse_state/equipment-restored.png) · [星球收起](evidence/collapse_state/planet-collapsed.png) · [星球恢复](evidence/collapse_state/planet-restored.png)。收起两图及星球恢复图已实际view_image；原模型仍为待原组修轮廓的R6，本组未动模型或贴图。

## 固定证据与覆盖边界

[三组43项记录](evidence/observations.json)全部通过；[同版实际运行日志](evidence/godot-live.txt)无脚本/资源错误，仅既有Xorg VSync警告。[Godot4.7.2解析](evidence/godot-check.txt)、Git diff检查通过。[环境、来源和文件哈希](evidence/environment.json)列明准确输入方式及未改函数。

使用同一正式main、真实Session/native、固定4.7.2和1440×900原任务环境；隔离/tmp存档沿之前已标明的临时开放/已建星球夹具，用来看到原反应炉滑杆、重铸列表和星球收起。没有自然解锁/建设通过结论，没有导入/新游戏确认成功、实际重铸、全保存故障、全模块自然流程、V0、整屏美术或Windows/DPI通过结论。原装备/星球及标题背景退出窄修文件未改。

当前无权限/运行阻塞；三项只提交修复候选及本组证据，关闭与否由原审复核，不自行扩大审核结论。
