# AI科技工厂美术与页面
- 目标：首代组装场景、独立覆盖抽屉页及统一机械科技图。
- 基准：main 52a87c0e8db7e0fd5a9e4c01882a60515411bdca；参考分支 30b3d2d56a94d0654dff107f6f4f52c0e0d70320。
- 范围：新页面脚本与新资产。禁止修改 main.gd、game.gd、配置及测试；入口交功能线程。
- 停止条件：独立页面可运行、机械科技可区分、首代动作可见、交付截图和短动画证据。
- 精确定位：scripts/hightech_workshop.gd 的 setup/_process；scripts/main.gd 的 build_hightech_tab；docs/tasks/AI_TECH_TREE_20261017.md 的 UI 与配置；docs/ART_GUIDELINES.md。
- 验收：方向 JPEG 已查看；首代画面改为背景、八台设备和探针静态资产分层。Godot 4.7.2 页面解析、GUI 截图、抽屉鼠标交互、信号、隐藏态和短动画见 `docs/tasks/ai-tech-art-20261017/evidence/`。
- 剩余：证据快照为契约样例；父线程核对游戏真实快照和高负载性能增量。美术分支不合 main。
