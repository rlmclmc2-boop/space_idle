# H2模块安装交接：现有事实与所有者确认

请求对象为原模块组，通过各自Git分支交付说明；不需改代码、不要求为65px重排，不新建工作区。整体线程引用固定提交收集结论，随后才决定顶部方案。以下源码事实由共享宿主线程只读核对，**不是模块所有者确认，也不是最小可读尺寸验收**。

## 原组需交回的最小说明

- 固定commit、内容根路径、当前正常画布/宿主位置。
- 当前顶部哪些区域已被局部标题、等级、对象选择、操作和弹层占用；坐标系、矩形、字/图可见边界。
- 可分离的全局品牌/钱包/导航，与必须保留的局部读数或操作分别列出。
- 当前可读安装尺寸、必要最小字号/控件尺寸、不得裁切/缩放的区域；若没有经确认的最小尺寸，明确只确认当前尺寸或列缺证，不要求新增测试。
- 自有非模态/模态、焦点/输入占用、隐藏/恢复责任；缺少的最小呈现通知写为缺口，不冒称已实现。
- 对H2“保留808×900、仅替换重复顶部”的约束或冲突；无需先同意65px共享带。原组不改main，宿主负责解决冲突。

建议各组将说明放在各自现行交接文档附近，回报Git提交与路径即可；不要求复制本模板或新增通用协议。

## 已取得的Git事实（待原组书面确认）

| 模块 | 固定代码/状态提交 | 现有安装与顶部占用 | 当前可读尺寸口径 / 尚缺 |
|---|---|---|---|
| 装备 | 运行代码冻结`5b4f72331038622ce739578fcdf3823a0a0b4716`；方向状态`9ba65fa029f8badbf9233e54571cd60e471a4967`，续核`8ffb9db36f923e61a40809e107cac60c5dfcb599`未改冻结Control | `equipment_panel.gd`根808×900；品牌(24,10,160,34)、钱包(204,16,590,30)、全局副标题(24,52,380,28)；局部装配标题(35,104,236,30)、全部装备升级(614,96,174,49)。 | 当前根808×900事实，不缩小；全局副标题到y80，H2替换65px仍须拆除该全局副标题，不能把y65以下自动判成设备净空。槽位显示正在独立调整。需原组确认全局元素可分离、正文顶部/批量模态边界及当前实际可读安装说明。 |
| 反应炉 | 最新读取`4e1c4c2b523998aa1471ed5dd154b6bebc80bd5b`；宿主交接仍15885107/e77 | `reactor_scene.gd`根808×900；`reactor_stage.gd`当前绘制65px标题带；局部模块名(26,18,170,28)、等级(612,23,170,28)确在带内；设备源板共同比例0.6、原点(96.8,20)。最新效果18px、供能附值14px；底操作台在y809..886。 | 808×900保持；等级是必须保留的局部读数，不能被资源/导航盖掉。需原组确认现有等级安置/标题拆分、设备上沿不可裁边界及实际最小可读口径。不要求重排四向短接或改变59dd方向。 |
| 星球 | 顶部源码固定`4368ca573545bc9df2112dfe636c7ca735a5a817`，续核`aa6183c12c943934aa262f64b786eb54e81aac0d`新增征服详情未改下列顶带/安装尺寸 | `planet_panel.gd`源码custom_minimum_size=760×740，候选main实际给808×900；90px顶部品牌/钱包/“星球探索”带，钱包(200,14,580,30)；视觉从y90起，控制首行y112..156，抽屉(22,278,width276)。 | 760×740是声明值，不能当实屏可读确认；当前取证为808×900。65px统一带不能自动替代90px局部顶部，需保留/分离y65..90内容事实。需原组确认当前安全区、抽屉/模态与最小实际可读说明；不改球面/轨道/设施布局。 |
| 其他现有模块 | 宿主e77的`_setup_growth_panel` / 各`src/ui/*_panel.gd` | 科研/强化/船员/星系/超空间及更多内容当前在ScrollContainer/VBoxContainer中，未交付808×900专属内容根或固定顶部安全带。 | 顶部导航映射已设计，但仍须共享宿主核挂载容器和现有内容；不能从三个独立模块推导其余全部可装入，也不让原组按新尺寸统一重画。 |

## Git引用

- [装备冻结代码](https://github.com/rlmclmc2-boop/space_idle/blob/5b4f72331038622ce739578fcdf3823a0a0b4716/space-battleship/src/ui/equipment_panel.gd)、[原组最新状态](https://github.com/rlmclmc2-boop/space_idle/blob/9ba65fa029f8badbf9233e54571cd60e471a4967/space-battleship/docs/ui-redesign-plan/g1-internal/equipment-image-design/upper-display/README.md)。
- [反应炉最新Control](https://github.com/rlmclmc2-boop/space_idle/blob/4e1c4c2b523998aa1471ed5dd154b6bebc80bd5b/space-battleship/src/ui/reactor_scene.gd)、[Stage](https://github.com/rlmclmc2-boop/space_idle/blob/4e1c4c2b523998aa1471ed5dd154b6bebc80bd5b/space-battleship/src/ui/reactor_stage.gd)。该内部候选未被本线程集成或宣称通过。
- [星球最新Control](https://github.com/rlmclmc2-boop/space_idle/blob/4368ca573545bc9df2112dfe636c7ca735a5a817/space-battleship/src/ui/planet_panel.gd)、[候选宿主挂载事实](https://github.com/rlmclmc2-boop/space_idle/blob/4368ca573545bc9df2112dfe636c7ca735a5a817/space-battleship/src/main.gd)。本线程仅取事实，不继承另一分支main修改。

## 确认记录

目前尚未收到原组针对上述六项的书面Git确认；将按实际提交追加。已知反应炉等级和星球90px带说明：65px不能先冻结为各组安装标准。H2字体排布实验只能支持宿主梁，不证明模块顶部冲突已消除。
