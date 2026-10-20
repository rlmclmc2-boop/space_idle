# Cannon task — narrow release candidate
目标：108080a7基线重打包最终八舰/旋转武器，排除否决中间稿和重复报告，保留必要显示/只读接口/测试与自包含复现来源。
来源：707981f3；父线程main快进被自动审批拒绝（229文件范围过宽），main未改变，本轮不重试。
分支：art/em-turret-release-20261020；独立worktree，不改原候选/默认分支。
内容：最终9runtime PNG、最终源atlas/selected emitter/批准原稿、紧凑输入JSON+importer、3个表现/只读脚本、原QA/3个tests、末次8+2原窗口证据。
验证：重新导入9PNG字节同707；素材检查通过；必要表现/接口/QA/capture代码同707，渲染字段仅来源路径改名。复用707原932/0图形结果，不重跑图形或另开复测。数值/编队/中心判定不变，1/2/4仍接口+隔离展示。
交付：evidence/em-turret-integration-20261020/RELEASE_SCOPE.md精确分类清单及repackage-check.json；新Git候选待父审，不合main。无执行阻塞。
