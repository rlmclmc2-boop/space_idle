# 共享宿主运行接入候选 H1

当前组合：[反应炉R4接入](reactor-r4-integration/README.md)，代码`db94845a`，原组ae0508ee内容已挂入当前公共宿主，16项必要接入观察通过；原布局Astra已亲看五图并核接口，共享接入范围无新增P1/P2。模块浮框/滑杆/底部覆层仍归原组，不扩大为整屏美术通过，不合main。

既有记录：[装备接入](equipment-owner-integration/README.md) · [星球R6接入](planet-r6-integration/README.md) · [旧标题底板退出](chrome-strip-fix/README.md) · [三项P2](p2-review-fixes/README.md) · [画布裁取回归](collapse-canvas-fix/README.md)。原Astra已限定关闭三项P2及后续裁取，无新增P1/P2；本次原实现保持，不扩展全窗口/DPI/自然流程/V0。

## 以下为首轮80e基线记录（后续组合以上方固定入口为准）

代码：`design/shared-host-shell@80e5463ff36f457b9e178315a5cf4b521b871068`。用户经根线程明确要求继续已授权顶部入口、通用UI、区域契约和真实业务接入；本候选据此推进。未合main，待原根审/独审；不声明整屏视觉、Session全系统或V0通过。反应炉新图仍由原组按[808×835作图范围V1](../reactor-drawing-v1/README.md)制作，未用被否决的侧框背板顶替。

## 已接入的运行范围

- 公共顶部位于左808×65，真实钱包消费Economy.balance_rows格式化文本及budget_changed；未登记余额以零显示。首96px为各视图自有上下文，反应炉使用同一presentation_model快照中的对象＋等级。资源详情显示经济模块实际返回的所有币种，未在宿主重算Amount。
- 8个主入口：装备、反应炉、科研、强化、船员、星球、星系、超空间。更多中的舰船、航程、属性、档案、通知、设置、重铸分别接原视图/原命令，另有收起/恢复。原“舰桥面板”和嵌套TabContainer入口已移除。开放来源逐项保持14§6.1，缓存失效只接真实公开通知。
- 全部视图只创建一次。旧舰桥中的现有VBox面板各自放入(0,65)/808×835的滚动宿主，边距16；装备和当前反应炉旧场景仍808×900，接口仅隐藏重复全局标题/钱包，未缩小主体或下移内部控件。这里没有把其他原组的新稿视为已安装。
- 装备、反应炉补最小本地视图端口：set_shared_host、has_exclusive_ui、exclusive_ui_changed、prepare_host_hide。context_slot归宿主管理、其子内容归视图；backdrop参数本轮不使用。普通切换保留实例/选择/草稿/滚动；自有模态或原生Window未结束时拒绝切换。实际Session替换/退出才强制清理自有弹层和焦点。
- 装备批量仍在模块层9，公共导航层10；独占时只禁顶部入口并用透明控件阻断右战场鼠标区，不覆盖批量按钮。main的Space与CampaignView的G共用只读UI门禁；输入框、原生弹窗、公共弹窗及原引导均阻断快捷动作，未新增暂停规则。
- 盾甲、航程、即时统计、暂停仍在原逻辑视口；只迁重复钱包和保存/停止状态。常驻教学文案已移除，快捷键保留。原SubViewportContainer输入映射和BattleView唯一伤害回执消费不变。
- 原设置、保存、导入、新游戏、重铸callable仍按原事务运行；既有battle/growth偏好格式保留，不新增存档字段。动作反馈留在其路由上下文，公共状态按钮可复看最后反馈和保存故障。

## 实际证据与边界

[普通装备整屏](evidence/equipment.png) · [更多入口](evidence/more.png) · [设置](evidence/settings.png) · [通知](evidence/notifications.png) · [装备批量](evidence/equipment-batch.png) · [收起](evidence/collapsed.png) · [真实余额详情](evidence/balances.png)

固定Godot4.7.2、生产Excel及真实native/GameSession，在本原任务内进行必要运行观察。临时驱动加载正式main场景、触发已连接按钮信号和真实Input事件；未建立独立测试工程、未提交测试runner。结果见[23项观察记录](evidence/observations.json)、[实际运行日志](evidence/godot-live.txt)、[解析检查](evidence/godot-check.txt)、[环境/代码/图片哈希](evidence/environment.json)。

23项均通过：启动、15路由、唯一活动视图、原投影、更多门禁、设置/通知切换、输入焦点与释放、实例保持、批量阻断切换及Space/G、收起恢复、8个未开放入口拒绝、正常Space/G正向对照、真实钱包文本对应。实际余额含经济模块返回的非零时空微粒，没有注入余额或解锁。字体cmap另核shared_host全部非ASCII文字符号，无缺字。原生构建成功；Linux绑定和API哈希与原固定环境一致。运行日志只有Xorg驱动不支持VSync警告，无脚本/资源错误。

以下未由这些证据覆盖：未开放模块的正向全套操作、普通鼠标拾取全链回归、Session导入/重铸替换成功全流程、长指数实钱状态、Windows发布包，以及三原组新候选的装配/品质。模块截图沿旧e77运行场景，只证明公共接入，不能据此批准装备冻结稿或旧反应炉工业稿。

## 后续最小接入

1. 原根审/独审按本代码候选及证据评共享职责，不重新开启已通过的金额/字体设计项；本轮新增运行改动正常审查。
2. 装备原组在其U1分支接纳同一最小chrome/独占端口，内部槽位/下方操作归原组；星球原组按自己的全808×900场景补同类端口，移除旧VBox占位路由时只更换注册视图，不改业务端口。
3. 反应炉新稿使用已发布内容根(0,65)/808×835；当前旧反应炉仅兼容占位。新图到位后由宿主接入该视图，保持战场映射。无固定97px侧带，不再铺旧侧框填空。
4. 原模块未提供新图不阻断其他公共入口/输入工作；实际未覆盖项单独列明，不把全模块可装入、65px对所有独立稿可读或V0写成事实。

本轮没有真实阻塞；待审与新美术属于上述隔离后续，不影响本次候选发布。工具、native产物、生成配置、缓存、临时驱动及隔离存档均不入Git。
