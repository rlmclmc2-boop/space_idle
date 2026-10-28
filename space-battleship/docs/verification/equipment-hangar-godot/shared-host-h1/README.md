# 装备对共享宿主H1的最小端口适配

**最新用户状态：本批视觉放行已撤回，待修/待根唯一审核。** 此页旧源码、图与限定结论保留为历史事实，不作为当前视觉通过；后续[整体排版修正候选](../workbench-optical-revision/README.md)已内部实现，仍待审，真实三资源来源缺口另明示。既有业务保护/U1基本方向不重开。

装备运行源码 `551a4f2b0262b9f8291bb6a13b024c32a37ea341`，原目录 `/workspace/space_idle`、原分支 `implement/equipment-hangar-godot`。对照 `design/shared-host-shell` 文档提交 `dfe43cbf03d5ae5e03f64a669f8b4466dc1d38be`、运行代码 `80e5463ff36f457b9e178315a5cf4b521b871068`，唯一规范入口为该固定Git对象的 `space-battleship/docs/ui-redesign-plan/shared-host-shell/runtime-h1/README.md`。

已正常fetch候选分支，随后仅用git show读取固定文档及equipment/main/shared_host必要范围；无checkout、合入、新工作区，未把H1的旧装备实现覆盖回来。参考对象与文件SHA见[h1-reference.json](h1-reference.json)。当前装备分支的main没有安装H1，不能把下面模块端口检查称作两分支实际组合通过。

## 具体兼容状态与责任

| 项目 | 5d414d4a前态 | 当前551a4f2b已具备 | 宿主责任或未覆盖 |
|---|---|---|---|
| chrome端口 | 无set_shared_host，重复标题/钱包不能由宿主隐藏 | 同H1签名 `set_shared_host(enabled: bool, context_slot: Control, _backdrop: Texture2D = null)`；仅隐藏“远航舰桥”“战力维护 / 装配”和本地钱包，false还原；backdrop同H1暂不使用 | H1的808×65栏、经济balance_rows及budget_changed由shared_host拥有；本模块不读取/绘制公共钱包 |
| context_slot | 无 | 宿主仍拥有slot；本模块只创建96×26“装备”Label，反复注册只回收本模块的旧Label，detach/exit只清理自己的caption，不删slot或宿主其他子节点 | H1 `register_route`创建slot并按路由控制显隐，H1主题/CanvasLayer10负责最终渲染；本检查没有安装该层 |
| 原尺寸 | 808×900 | size与custom_minimum_size均仍808×900，根坐标不下移、不缩主体；218/244/264px状态台及费用/回执均不变 | H1 README明确装备旧场景继续808×900，只隐藏重复chrome；不套反应炉的808×835，也不加入97px侧带 |
| 独占查询 | 无 | `has_exclusive_ui() -> bool`精确返回本地批量Panel或OptionButton Popup可见 | H1 main每帧轮询模块独占，并递归检查其他可见Window；普通回执tooltip不由装备端口声明为独占，泛Window兜底的最终判别归宿主 |
| 独占信号 | 无 | `signal exclusive_ui_changed`无参数；批量开/关、下拉Popup可见性变化均发；实测状态序列batch开启→popup开启→popup关闭→batch关闭 | 当前H1 main采用轮询，没有连接该信号；后续订阅仍可直接读has_exclusive_ui，不新增路由/业务信号 |
| 普通离页/收起 | 无prepare_host_hide | `prepare_host_hide(force: bool = false) -> bool`：有批量/Popup返回false且保留层；非独占返回true并释放本视图Control焦点，不主动隐藏/重建视图 | H1负责先调用此端口、随后切路由/收起；show_route复用同一实例，选择/数量等留存 |
| Session替换/退出 | 无模块强制清理口 | force=true关闭本地Popup、批量Panel、frame、blocker，再释放本视图焦点；`_exit_tree`回收本模块context caption | H1 `_prepare_host_release`在替换/退出前调用force，继续由main清理原生Window和路由；本轮未执行成功导入/重铸/Session替换全流程 |
| 弹层与焦点层级 | 本地批量z19/20/21，没有宿主独占信息 | 保留本地批量z序与完整控件；关闭时同时藏Popup；实测force及普通hide都释放所属焦点 | 模块仍在H1 CanvasLayer9，公共导航在10；顶部导航禁用、右战场透明输入遮挡及Space/G门禁由H1 main负责，装备不遮公共导航/战场、不新增暂停规则 |
| command_finished | 已有 | 保留原Dictionary信号及last_result/短回执/完整tooltip；无业务或消费语义改变 | H1未额外连接装备command_finished；装备成功/错误继续在本地路由上下文显示 |

本轮没有新增完整模态Tab循环/回焦到开启按钮的策略，也没有以端口存在推定该体验已覆盖；已检查的焦点责任仅为普通/强制离页时释放所属焦点。H1组合后的焦点循环、普通tooltip窗口兜底、全局快捷键/导航/右侧鼠标阻断须由整体组在实际组合版本核对，模块不越界改main。

## 实际必要检查

[原执行驱动](capture-driver.gd.txt)、[四条生命周期记录与独占事件](observations.json)、[真实运行日志](capture.log.txt)、[4.7.2解析检查](check.log.txt)：当前正式main/Session/native正常启动，一次端口生命周期观察exit0，`EQUIPMENT_H1_PORTS_COMPLETE failures=0 records=4`。仅此组必要观察，没有复跑购买/玩法/四保护全链。

1. 正常模式本地chrome/钱包可见；启用shared隐藏三项，保留舰名、局部费用/回执控件；808×900及当前218px状态台矩形不动。反复注册只替换自身caption，不删诊断slot中的宿主sentinel。
2. 真实鼠标打开批量，再打开OptionButton原生Popup；has_exclusive_ui均为true，普通hide两次均拒绝；四次事件状态与真实可见性一致。
3. force关闭Popup、批量、框及遮罩，释放所属焦点；无独占时让数量按钮实际grab_focus，再普通hide可释放。hide/show保持同一个Node实例和选择/数量/MAX状态，钱包装备不变，不付款/装配。
4. 禁用shared后恢复原chrome/钱包，只删除自身caption，宿主sentinel保留。退出树caption清理是源码核对，未将其单列成已运行的Session替换案例。

[chrome隐藏诊断整屏](01-local-port-chrome-enabled.png)与[真实批量/下拉弹层整屏](02-local-batch-popup-exclusive.png)均已实际view_image。**图片是当前旧main加诊断Control slot，不是H1整屏**：顶部仍有旧main拥有的“舰桥面板”，诊断context在根层不代替H1层10，空白顶部不能作为共享宿主设计图或组合失败/通过证据。图片只辅助核本地chrome退出、局部工作台不位移及实际弹层。

## 保留范围与交付结论

相对5d414d4a，运行只改equipment_panel.gd：记录两项原global Label引用，补四端口/自身context回收，批量及Popup发独占通知，关闭时收回本地Popup。没有覆盖H1旧装备代码；原状态布局、未解锁完全空白且固定原位、U1武器、短回执/完整tooltip逐函数不变。

[保留依据](preserved-boundaries.json)核对18个初始化/布局/候选/刷新/命令/回执函数、7个宿主/Session/Owner/战场/拾取/几何文件与5d逐字节相同；main及公共导航没有修改。所有交付文件和固定源码SHA见[manifest.json](manifest.json)。缓存、生成配置、个人存档、工具/native产物不入Git，原tmp保留。

**结论是最小模块端口已对齐、局部生命周期检查有证据；实际H1组合尚未安装/验证。** 整体组接纳本分支最新装备时应保留此文件内部实现，只处理宿主端口接线，不能整文件换回80e5463f旧装备。组合后的15路由、Space/G、右战场拾取/投影、Session导入重铸/退出成功流程、焦点循环/全局Window判别、V0/V2和Windows/DPI均未扩大覆盖；停车、完整配装、其他三档边界保持。

当前无运行任务、无权限阻塞，未发生实际上下文压缩。普通Git推送原候选分支，只交根审/整体组；不合main、不force、不使用Library/Space。
