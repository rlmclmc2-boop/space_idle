# Cannon redesign — selected51aae1ac integration complete
目标：用户暂定51aae1ac后停止改稿，沿原任务导入该素材及07覆盖，八版原窗口实机交父审。
范围：独立runtime PNG/manifest、未启用movable_gun描述、原隔离展示的逐组件尺寸/可视端口；未生成新设计。
禁止：不改舰体/固定底座坐标/生产数值/编队/船中心，1/2/4仍仅接口及原隔离展示，不启用生产配装，不合main。
基准/分支：51aae1ac，art/cannon-redesign-20261020。
交付：evidence/em-turret-integration-20261020/README.md，8张1372×883原窗口PNG和原夹具±35度两帧，日志/JSON；素材来源51aae1ac，覆盖来源3bed1e2e。
验证：一次资产检查+原夹具一次图形运行932检查0失败，49次开火/62次命中；无独立单测/复测。轴心/端口/覆盖/绘制框/retained与canonical实机已看。8舰体PNG、24坐标、display_size、active配置、生产scripts/game_data/Excel冻结。未接触用户存档，未做native整场/性能验收。
状态：候选接入完成，Git交父审，不合main；无执行阻塞。
