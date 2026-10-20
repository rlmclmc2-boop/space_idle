# Cannon redesign — same task, 06 coverage-only review07
目标：暂停新画，复用06炮身，按固定底座外承载面修正显示覆盖，只交正常比例对照和转向。
禁止：不生成新炮图、不单独放大炮管，不变舰体/底座坐标/生产资源/接口/配装/数值/编队/存档，不接入不合main。
基准/分支：1471e0ff，art/cannon-redesign-20261020。
交付：cannon-coverage-review-07/normal-comparison.png、direction-check.png、design-board.png与测量JSON；入口evidence/cannon-redesign-20261020/README.md。
检查：外承载面三条水平扫描，逐底座alpha边界限幅；0/±35/±55共240探针，全部主连通体alpha>230像素无越界；含炮管外接圆任意转向最小间隙约10px，不互叠。06PNG及生产/QA/导入器/测试冻结，未启动Godot。
结论：主体18.5–24.6px，主案例可读性改善；锚定精英/反应BOSS部分底座受边界限制，不能都放满95%，部分同舰尺寸不同；不宣称比例彻底解决所有位置。Git交证据待父审，无执行权限阻塞。
