# 同轮隐藏控件与刷新检查

固定生产源码：8fe99e95529b42752cc79d4c7b00769a07de3b4b。作者同线程审查/运行，非独立审与用户验收。

- `_fallback_header`和旧宿主入口在shared模式隐藏，保留非shared宿主兼容；没有独立process。空槽内属性/购买/比较等控件隐藏且执行键禁用，空槽不是安装卡；离屏卡整张隐藏并释放其焦点，展开层随离屏关闭。
- Popup每次关闭立即hide并queue_free，重开先关旧层。tooltip只有悬停时建立0.5s单次Timer，用ticket取消失效展示；隐藏tooltip不参与动作。fee缓存按资源保留控件，复用两种实际费用，不按购买次数增生。
- 信号仅在EquipmentPanel构造时连接一次。slots_changed记录受影响槽；预算变化设values_dirty；可见帧优先结构、再合并数值、再局部槽，一帧只消费一次。预算不变直接返回；隐藏页_process早退，保留dirty供返回刷新。
- 单槽付款改变钱包，因此所有槽的费用/可付性重新读取Owner（MAX还依赖余额）；signature只更新实际变化的可见字段。数值升级不发options/loadout结构信号；当前场景以舰体/槽装备ID/选中槽作签名，付费级变化不重绘。全部升级同次Owner合并提交与UI合并帧处理。数值提交走native set_player_values；配置/几何安装仅换舰换装等结构变化走commit_player。
- `command_finished`不连main全局刷新链。`exclusive_ui_changed`只同步模态/导航准入，不刷新其它模块业务。
- 故障停止后“比较”随Owner不可用禁用，直调也不再创建空结果Popup。本轮消除成功后残留上次失败toast，避免接受后的界面仍有旧拒绝；装饰只在原场景重绘时绘制，不加新节点、信号、计时或常驻开发UI。

性能正式证据见performance-operations.json，实际1e12铁/1e6材料、8槽、同非战斗离港场景、每次支付都核预算变化、目标8Hz、四窗各4s。不限帧、不录影，Godot4.7.2/1440x900/llvmpipe既有native；没有同源历史基线，不作前后优化收益、战斗性能或目标机通过结论。全程节点1413，连接数[2,2,1,1]不增；逐槽/全部各30次均真实Owner接受，预算各变30次，结构刷新/装备场景重绘/native配置提交均0；各30次数值合并刷新。逐槽240次比较读取但仅30个槽内容变更；全部240次读取/更新对应8×30。隐藏页的额外同线程读数在single-operations.json，未新增独立复测。

诊断证据：日志前缀EQUIPMENT_COMMAND_FAILURE，仅写reason/error/stop_reason符号原因和fault/commit_status/running，不dump钱包、payload、保存路径；非符号文本redacted。真实不足和首防御槽拒绝保持领域反馈；未知为显式publisher注入后Owner生成，未声称发生了真实native崩溃。未自动重试、不伪成功、不假定已回滚；停机后重复命令仍Owner拒绝。
