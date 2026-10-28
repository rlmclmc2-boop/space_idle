# 装备机库视觉修订：供原独审的固定候选

固定运行源码 **946f71d9f285540948118db5572fa2976fa2a68d**；原目录 `/workspace/space_idle`、分支 `implement/equipment-hangar-godot`。仅装备UI与专属机壳/支承素材修订，无main、业务、配置、battle、尺度或其他模块修改；未合main。本记录是制作与定向验证结果，**不自判图04还原或整体视觉通过**。

## 同版画面与实际操作

- [现装/候选比较](candidate/03-cruiser-cannon-comparison.png)、[防御候选](candidate/16-defence-candidate.png)、[操作后的巡洋舰](candidate/15-final-cruiser.png)。
- [武器+1材料](candidate/04-single-plus1-material.png)、[+10报价](candidate/05-plus10-quote.png)、[MAX报价](candidate/07-max-quote.png)、[MAX成交](candidate/08-single-max.png)。
- [冷却](candidate/09-switch-cooldown.png)、[真实游戏时间到期](candidate/10-switch-ready.png)、[批量部分成交](candidate/12-batch-partial-result.png)、[关闭重开保持](candidate/13-batch-result-retained.png)。
- [防御+1报价](candidate/17-defence-quote-0.png)、[+10报价](candidate/17-defence-quote-1.png)、[MAX报价](candidate/17-defence-quote-2.png)及同目录18系列实际成交。
- [长金额/多资源MAX](candidate/19-long-max-multi-resource.png)、[资源不足](candidate/20-insufficient-resources.png)、[原始操作记录](candidate/operations.json)。

真实Godot 4.7.2主场景、Session/native；全部游戏图为根视口1440×900原像素，未裁切、缩放、拼接。鼠标事件实际经过viewport GUI。初始启动pause仅user，没有恢复暂停。巡洋舰、进度100、等级和钱包采用明确记录的受控save-state restore及实际native refit；不冒充自然赚取进度或用户存档。购买、换装、冷却、MAX、批量都调用原所有者，未用UI金额公式/假响应。

操作检查 `failures=0 records=14`。武器+1实际1600铁/10简并物质，+10实际49800铁，MAX实际19级/184万铁/20简并物质。防御+1实际1300铁，+10实际41500铁/10简并物质，MAX实际20级/184.99万铁/20简并物质；逐笔原Amount核对钱包减actual spent和实际付费等级增量等于count。真实换装拒绝EquipmentSwitchLocked，游戏时间10.25秒后成功。批量仅武器2/3各+1，总2600铁，未成交槽保持，底层误点受阻，关闭/重开结果保持。长钱包MAX由真实所有者报414级，1.145×10^39铁及2730简并物质，两行资源与完整格式化金额均可见，金额字号17未缩小。真正不足资源的原所有者调用拒绝另记在JSON。

## 视觉改动与字体实测

完整机库台面扩为330px；真实控件位于台面。槽终端为有深度的象牙装甲/深蓝机壳，支承加厚，关节中心对准终端底部插座与原挂点，舰体/武器覆盖末端；正式manifest与PNG身份、锚点均保持。槽名称/主值/辅助事实分层，升级费用按资源分行并与图标分开。现装/候选是主要两列比较；重复槽数横条移除。批量以实际总花费和成交项为主，未成交与余额次级；未知与缺明细不推断零成交或已确认余额。

新素材为旧执行者的原始ImageGen PNG完整复制，沿用机库与已批准图04参考，仅运行Atlas/NinePatch显示；原工具输出、提示词及hash见 [sources.json](../../../../assets/ui/equipment/hangar/sources.json)。未重画正式舰体/武器、防御图标或其他模块。仅新两张PNG所需的.import随素材提交，其余本地导入元数据保留未提交。

装备专属数值OpenType键2003265652为400/600，不扩大修改共享旧字符串wght/embolden。基础TextServer metadata仍100，不能以它声称变体就是100或600。[真实栅格](font-raster.png)/[指标](font-raster.json)显示：相同24px样本“装备 攻击力 12.4 K”，100默认/字符串wght样本宽193、coverage478.98、实心像素36；400宽198、coverage1115.95、实心像素673；600宽201、coverage1531.76、实心像素1168。数值坐标读回400/600，实际字形/宽度均不同，非uniform embolden。图的四行依序100/400/600/字符串wght450；该图是隔离字体实测，不冒充游戏截图或正式玩家UI。

## 四项原关闭修复的同版定向回归

[原始runtime.json](regression/runtime.json)及[日志](regression.log) `failures=0`：

- 未暂停真实活战斗game_time3.10→4.7167；97次经济通知钱包不变，槽位/选项/比较/MAX读取均0；仍70次battle draw、3次统计更新，节点增删0。不是冻结模拟；定时移动另一个1.60游戏秒窗口96通知亦0读取。
- 免费武器80、防御20由原舰桥反应炉实际“分配”按钮执行，每项恰1条comparison依赖通知，current/upgrade/candidate实际改变并与所有者一致，无额外装备点击刺激刷新。[武器](regression/free-weapons-return.png)/[防御](regression/free-defence-return.png)。此为既有接口回归，无反应炉实现修改。
- 真实生成且已拥有的定时掉落，仅经验证受控保存将位置置于逻辑x32/540；两次实际根坐标点击移除目标且原Amount核钱包，左空白边带误点不拾取。右区域632×900内scale保持双轴0.9375、投影(855.875,0,536.25,900)，视觉/拾取共用原变换。[左前后](regression/edge-left-before.png)/[左后](regression/edge-left-after.png)、[右前](regression/edge-right-before.png)/[右后](regression/edge-right-after.png)。
- [未知回执](regression/batch-unknown.png)及rejected/not_submitted/accepted缺明细检查为真实Control的**呈现边界输入**，没有伪造native致命故障或财务响应。未知仍显示未确认，不显示等级保持、成交后余额或0成交；正常部分成交另由实际所有者回执证明。

首跑误复用操作驱动退出后留下的受控存档目录，主场景进入`recovery`暂停（game_time0→0），导致12项准备/观察失败。其原始JSON、日志和PNG保留在 [regression-recovery-window](regression-recovery-window/runtime.json)，不能当通过。仅受影响回归改用全新独立/tmp设置/存档目录补测，并加启动无recovery断言；没有改保存逻辑、删除存档或重跑已完成14条操作。预览的首次新设置未跳教程遮挡图保留本地refined-preview，不作最终证据。初次隔离字体探针窗口过小导致采样越界，正确1440×900栅格探针结果以上述JSON为准；失败大日志留/tmp，未当有效指标。

## 追溯与剩余范围

[manifest.json](manifest.json)将两次运行原始source_hashes逐字节核到固定Git源码；操作驱动在源码提交前启动，source_commit环境标签为空，未改写成已运行固定提交，也未为改标签重跑。同版成立来自实际哈希相等。驱动文本、引擎日志、每张图和JSON SHA256均在此目录。正常运行环境沿 [environment.md](../environment.md)，复用既有Godot/native/config，无重新构建环境。

费用/终端材质、支承与图04感觉、字体层次以及较长MAX主值贴近左台右缘的余量，仍交原独审按原像素评价；本轮只证明列明实际交互与原修复定向结果。未覆盖全舰型/全部长值组合、长期性能、Windows/DPI、其他模块或整体游戏。灰色“舰桥面板”仍是共享宿主，未擅改。当前无审批拒绝、未知外部操作或环境阻塞。执行者 `/root/equipment_visual_replacement` 未实际上下文压缩，固定候选后不接新批。
