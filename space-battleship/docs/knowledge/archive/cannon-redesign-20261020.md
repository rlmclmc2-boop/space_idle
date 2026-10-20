# Cannon runtime integration complete
目标：最终51aae1ac炮台及八舰体正式接入；不改配装、数值、船中心，不合main。
交付：运行候选24f0751d，art/em-turret-runtime-20261020，基于108080a7，18文件（15运行+3必要回归）。32101f46未合入。
证据：evidence/em-turret-integration-20261020/RELEASE_SCOPE.md；runtime/有8舰+2转向原窗口图、runtime.json/run.log，仅原任务分支保留。
验收：正式main.tscn 279检查0失败，31开火40命中；两个素材/配置检查PASS；canonical、retained、native显示view数学一致；未做native整场/性能验收。
数值边界：真实270005–270008各1武器，精英2/BOSS4只为烘焙底座数；active硬点/槽映射/profile/普通配置/旧几何冻结。game/authority/native execution/game_data字节不变。
状态：Git交父审，不合main。环境可用，无执行阻塞。
