# 装备实际压缩自然项交接（WIP，未完成用户验收）

原目录 /workspace/space_idle；分支 implement/equipment-hangar-godot。
最新已推送 HEAD e3fb94147895dce44f4d83d138c7edb2a9a7adbc，仅将 a54 用户退回状态固定；M2/旧交接没有宣称新实现完成。
当前唯一 tracked 修改 space-battleship/src/ui/equipment_panel.gd；未提交、未推送。
SHA256 12d453d9ced6fbefced788af9253fe16d92e0c883b7c5bd7811efb28b2e742cc。
同目录 runtime-draft.patch 保存完整差异，未动缓存、main/宿主/业务/config。

## 当前实现
撤除旧下方背景三片 draw 与 SVG/outline 叠画，改为真实单 EquipmentWorkbench Panel（16,610,776,286）及内部对象栏、升级/选择内容和统一按钮基线；原上方机库图仅绘源 y0..845。候选卡图上沿8px。删旧隐藏 _compare 与重复组装，同物仅显示当前主值/已装备卡，异物显示必要现装/所选比较和安装。回执在对象栏内部。既有关联公式仍来自 owner。
五档展示递进保持，正式可见舰尾锚映到机库源（594,730）即显示（404,547.1893），武器同源变换；该点是当前候选展示锚，不是新批准真实物理参数。
上方防御贴片完全停止绘制，无伪物理点/整舰战斗盾效果；身份由唯一侧槽+下方对象栏，既有舰名轻色强调作用域。真实防御候选仍在下方保留。

## 本次已完成预览，自此不再运行
Godot4.7.2 check-only 成功；真实 DISPLAY=:99 1440x900 预览同一次进程 session7285 已 exit0，preview.log 为 INTEGRATED_EQUIPMENT_COMPLETE failures=0 records=15。
驱动 /tmp/space-idle-workbench-rebuild-capture.gd；设置 preview-settings.json / preview-fresh-save 均在本目录隔离。
12张 PNG + operations.json：新局、cleared1、安装回执、长MAX、五档同机位、防御3槽。
记录覆盖真实锁拒绝/导弹安装、长值材质字墨边距、五档同源锚、3防御唯一选择/无native提交和钱包变化、控件树/边界。
source_commit=workbench-rebuild-preview 是明确工作稿标记，不能当已固定源码正式证据。

## 实际看图与限制
已逐张实际看五档 full screenshot，并看 cleared1、Heavy防御3。新下方无旧深蓝边缘/错壳叠层，候选图不贴顶，异物比较不贴卡底，回执入栏，同物无重复比较；五舰尾落同一平台内前侧标线，体量递进；无防御悬空代理。
这只是作者检查，不是根审/独审/用户通过。单一 Panel 仍是286px高；同物时右下空域明显，是否足够整体紧凑/材质符合用户预期待根实际看。停车锚候选亦待根审，不得仅凭几何等式宣布通过。
未再逐张检查 fresh/长MAX/安装回执及防御0/1 PNG（已由探针生成）。没有生成局部裁图、没有新固定源码采证/manifest，没有追加保护全链测试。

## 实际压缩与停止边界
本次预览完成附近发生实际上下文压缩。按原约定只收尾已运行自然项、实看关键图并留下本交接后停止，不接新批、不继续改/测试/生成。当前无运行命令，无工具任务。
剩余：根实际复看7项+空域与停车关系；必要修正；有针对性的无关刷新/交易证据（本次不是完整四保护复跑）；源码固定并用同版完整/局部图建立正式证据；M2/尺度参考如实更新；普通推送交原审。不能将本预览零失败、旧a54测量或旧防御图状态宣称用户已认可。
