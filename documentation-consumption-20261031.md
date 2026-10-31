# 各原组最小文档消费清单

根负责交原组，本线程没有直接改动/推送五条制作分支或main。禁止整分支旧树checkout、merge或整提交cherry-pick覆盖正在制作源码/UI/WIP。固定来源见ARCHIVE-SOURCES，所有该快照docs已归档并逐blob验证；有新提交或WIP先重新核时效与保全，不能因本清单删掉新工作。

## 共同规范（每组一次）

1. 从固定文档提交`928f2bdfc32b7e88a252a0b05a275aa0a27e5b4b`按路径消费`space-battleship/docs/game-design/`当前文件，排除11的可变状态表；精确路径见[机器清单](documentation-consumption-manifest.json)的current_shared_spec_files。含README、01–09、13/14、11模块契约、M/V、sources/open-items和当前conflicts，不复制任何history/reference/config旧副本。
2. 11当前状态表与`docs/ui-redesign-plan/README.md`仅按最新固定源合并短事实。07§5是唯一接替清理/审核主体规则，不另建每组规则副本。
3. 删除本组已归档的旧HISTORY/旧规范/保存证据等tracked文件及指向它们的正式导航。每组机器清单按读取SHA列出相对于现行docs白名单的移出项；先逐文件核它是否还是当前实际制作/构建输入，再应用，不能对最新WIP执行目录级清空。若某个当前生成源确实是制作输入，放正常authoring位置并保留依赖，不能把整包历史伪装成“制作需要”。
4. 资产README只消费对应本组当前M/V的短边界；不覆盖新模型的锚点、导入、制造依赖或许可证。明确退役interface、生成提示词/纯归因报告移出，实际模型/纹理/manifest不属于本次文档补丁。根上的船/炮塔、字体和星系技术说明保留当前制造/装配条件，旧证据不留。

## 四组入口（最小入口文件）

所有路径均以space-battleship/为根。每组必须将README内相对规范/依赖链接闭合；不复制HISTORY，入口不挂保留分支导航。

|原组|当前入口和必要父路由|按模块消费|接替必须保持的最新状态|
|---|---|---|---|
|装备|docs/verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md；父workbench-optical-revision/README.md|M2、equipment分册，assets/ui/equipment/hangar README只取现行边界|bb4c文档/81744运行已接R3；原独审限定可交用户，根16:10已发三图，现待用户意见，不回退待原审或等材质。|
|反应堆|docs/verification/reactor-centered-godot/evidence/b01-redesign/README.md；reactor-centered-godot/README.md|M3、reactor-asset-contract、reactor分册|519f已接R3且有最终同版连续片；目标机性能仍未证、未获本版独立视觉结论，不能写缺最终片或旧审已通过。|
|星球|docs/verification/planet-single-side-godot/visual-r17-curved-spine/README.md；planet-single-side-godot/README.md|M7、planet分册、D11当前结论|保留a40c源码662952与最新站/炉主形体、环下层/自由端未完项；maker原地继续，不能把本快照当后来WIP。|
|整体|docs/ui-redesign-plan/shared-host-shell/runtime-clear-zone/README.md；docs/ui-redesign-plan/README.md|13公共样式、14、当前资源契约|5df3d3dd已在3c公共源合入装备/B01，同版组合待原整体审核；不回退未组合状态。|

后台另消费05/06/07/09、14及persistence/resources契约、当前conflicts和11状态；D9规范按c38，不把main写成已去绑定。旧_save_files/_stage6_page/_stage6_session探针断言需原后台处理，本整理不改测试源码。强化两购买键待原模块按统一交互接入，不因文档更正自动认为实现完成。

## 必须移出的保存资料

共同：docs/game-design/history/**、reference/config/**及config-inventory、10-stage5旧合同、12旧删除清单、旧review审计记录；docs/ui-design-candidate/**；旧g0/历史交接正文；各HISTORY和README-*-history等。模块：各组旧稿/图/视频/日志/驱动/账本/纯来源JSON、已结束验收目录，统一留归档。四组当前README中的目标/有效约束/当前状态保留。

main已有enemy-presentation与equipment main-integration保存包也已从整理树移出，归档保留；不把仍支撑main的证据误当运行依赖。当前最小证据覆盖结论可在入口注明作者/独审/用户主体，但原始资料不留正式/制作树。必要源码、Excel、实际资产、许可证、制造输入及未提交WIP不按“历史”后缀误删。

## 消费检查与提交

只做文档链接/路径与原始blob核对，检查无通往旧资料的正式导航、无旧source状态覆盖最新退回、四入口相对路径完整。消费前后生产代码/配置/真实资产hash不变；若原组同时制作，则分清文档diff和本人WIP。普通提交/推送并返回固定SHA、审核主体与范围，不合main、不force、不删除分支。新证据以独立保留分支模块index.md交付给审核者，不再堆回制作入口。
