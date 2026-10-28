# 原装备候选 × 共享宿主 H1：实际接入

运行代码：`design/shared-host-shell@07a3682367e12103fc3dd5561b3b913f5b9f79dd`。原工作区续接，未新建任务/工作区，未合main。装备来源`551a4f2b0262b9f8291bb6a13b024c32a37ea341`，原组[端口交接与证据](https://github.com/rlmclmc2-boop/space_idle/blob/da317ba436a8fb4665b99d7d78cbf42e23f43bd3/space-battleship/docs/verification/equipment-hangar-godot/shared-host-h1/README.md)。本候选替换宿主H1的旧装备视图；其他共享宿主代码沿`dfe43cbf`。

## 接入与保留

- `src/ui/equipment_panel.gd`逐字节来自551a4f2b，SHA256为`0d4d043bb814f39fffeebab1fa376f139d66ecf9e979b04ae5cdaea8a1482c51`。保留原组U1、按状态重排的218/244/264px工作台、未解锁纯空位、短成交回执/完整tooltip及四个最小H1端口。未用宿主80e旧装备代码覆盖其内部。
- 仅取当前视图源码。实际引用的材质、字体、舰体、武器和原hangar-console素材当前分支已有；未带入原组分支的main/经济/反应炉差异，也未引入未使用素材。装备/战场业务、配置、几何、报价、付款与回执消费契约不变。
- 宿主调用原组set_shared_host隐藏三项全局chrome，并在自己层10的96×26 slot内显示原组“装备”caption。装备根仍(0,0)/808×900，内部工作台坐标不动；未套反应炉808×835内容根。
- 普通离页/收起调用prepare_host_hide，批量与Popup存在时拒绝；装备原组保持独占信号及本地关闭按钮。隐藏只复用实例；Session真实替换/退出仍走force清理。原组内部没有额外变动。

## 必要共享侧修正

初次组合实际发现：`main::_visible_window`把Godot生成的普通数值tooltip当成独占窗口，导致全局导航/战场门禁误开。实际窗口记录为PopupPanel、`unfocusable=true`、`mouse_passthrough=true`；它不能接键盘或指针。共享侧现只排除同时具备这两个被动标记的Window，原生PopupMenu/FileDialog仍独占。未按节点名称猜测，未删除菜单/模态保护，装备文件保持原样。

一次设置下拉诊断最初选中了FileDialog内部隐藏OptionButton（矩形位于0,0），并未实际打开倍速菜单；诊断改查设置VBox直接子项中的实际可见倍速下拉后，真实鼠标打开及门禁通过。此项不是设置源码变更。

## 实际组合结果

[33项观察](evidence/observations.json)全部通过；[真实运行日志](evidence/godot-live.txt)无脚本/资源错误，仅既有Xorg VSync警告；[4.7.2解析检查](evidence/godot-check.txt)与Git diff检查通过。[环境、代码身份与证据哈希](evidence/environment.json)。

- 15路由、唯一活动视图、公共资源文本、更多/设置/通知切换、收起恢复、未开放入口判定保持。真实经济模块余额包含铁、铀和时空微粒，没有注入钱包。
- 真实鼠标点击原战场(1124,450)，逻辑视口收到约(286,480)，对应原(855.875,0)/0.9375映射。装备批量打开后，同位置点击不再进入战场；关闭后重新投递。
- 真实鼠标打开装备批量和其原生下拉，独占为true；普通离页拒绝、公共入口禁用、右战场挡鼠标，Space/G不穿透；本地关闭按钮仍能点击。事件记录允许相同独占值的重复通知，不把信号次数当领域状态。
- 设置实际倍速原生Popup打开时同样阻断公共入口/快捷键；关闭后可切回装备。
- 正常状态Space暂停与G驻守正向对照通过；设置输入框占用时拒绝，切换撤离焦点。装备实例、选择/候选/数量/MAX跨切换与收起恢复保持。
- 实际数值tooltip可见，原生Window记录同时为不取焦点＋鼠标穿透；导航与战场门禁保持关闭，普通提示不被误作模态。

[装备实际整屏](evidence/equipment.png) · [更多](evidence/more.png) · [批量](evidence/equipment-batch.png) · [原生下拉](evidence/equipment-native-popup.png) · [实际tooltip](evidence/equipment-tooltip.png) · [资源详情](evidence/balances.png) · [收起](evidence/collapsed.png)。前三种装备状态及tooltip均已实际查看整屏，未据旧装备/单页裁图代替组合证据。

本轮是原整体任务中的必要接入观察，使用同一生产main、真实Session/native及固定Godot4.7.2；临时驱动只做UI事件/记录，没有新建独立复测任务或测试工程。未重新执行装备购买/玩法/所有边界；本轮没有购买命令，回执与状态布局的保留由原组固定源码逐字节身份保证。

## 后续边界

待原根审/独审。星球仍是宿主旧VBox占位路由，待其固定Git交接后替换；反应炉新稿仍按已交808×835范围由原组制作。未覆盖这两组的新稿装配、已解锁模块全操作、Session导入/重铸成功全链、Windows/DPI或V0整体验收。此后续不影响当前已完成的装备实际组合发布。无权限或运行阻塞。
