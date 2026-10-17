# AI科技工厂美术与页面
- 目标：首代组装场景、独立覆盖抽屉页及统一机械科技图。
- 基准：main 52a87c0e8db7e0fd5a9e4c01882a60515411bdca；参考分支 30b3d2d56a94d0654dff107f6f4f52c0e0d70320。
- 范围：新页面脚本与新资产。禁止修改 main.gd、game.gd、配置及测试；入口交功能线程。
- 停止条件：独立页面可运行、机械科技可区分、首代动作可见、交付截图和短动画证据。
- 精确定位：scripts/hightech_workshop.gd 的 setup/_process；scripts/main.gd 的 build_hightech_tab；docs/tasks/AI_TECH_TREE_20261017.md 的 UI 与配置；docs/ART_GUIDELINES.md。
- 已知风险：两张参考 PNG 在 Git 中解码失败，需获完好版本；功能线程的快照字段契约待协调。
- 下一动作：页面使用快照输入和选研信号，先实现首代受限绘制与覆盖抽屉。
