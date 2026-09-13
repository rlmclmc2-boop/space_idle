# 游戏 UI 与 QA

## CONFIRMED · 来源

原表仅明确横版实时画面、自动攻击、悬停拾取与重刷/选关（总览!A3:A10）。以下具体窗口与交互由 `scripts/main.gd`、`config_panel.gd` 确认；2026-09-13 用户要求已接入指定循环关卡选择，细则见 map。

## CURRENT

- 2026-09-14 用户要求敌人生命显示保留前两位有效数字，其余向下截断（123→120），达到千/百万/十亿/万亿用 K/M/B/T（1230→1.2K）。main.enemy_health 复用 number 输出；普通敌舰右侧和BOSS面板的当前/最大生命统一使用。实际生命及血条比例不变。

- 2026-09-14 用户要求资源显示切换：顶部“资源：总量 / 资源：每秒”按钮默认总量，再次点击切回。收益按最近60秒实际 collect 入账之和÷60，铁/钛独立，以两位小数和“/秒”显示；统计使用现实单调时间，暂停仍会过期、倍速不缩短窗口，启动不足一分钟也除以60。只统计本次场景会话收入，手动及自动拾取均计入，扣费/初始余额不计入；切换、换关及 UI 重建不清空，重启场景重置。此统计口径为本次实现选择。

- 2026-09-14 用户要求：关卡标题旁显示 BOSS 信息，未遇到显示“？？？”。复用敌机 des 描述（含抗性）；spawn_group 首次生成 BOSS 时记录 profile.bossSeen 并保存，按关卡隔离，死亡/重刷/重启不清除。旧存档已通关关卡视为已遇到；未通关且无遭遇记录的关卡保持未知。

- main.tscn 加载 main.gd，启动即战斗；界面只创建已解锁装备的升级按钮。循环、帮助、音效在游戏界面；升级按钮直连 game.upgrade。
- 鼠标移动/按下触发拾取；空格/Esc 确认新装备提示、关闭帮助或切换暂停；F1 显示 QA。新解锁以“继续”弹窗通知；相关推进规则只见 progression。
- 暂停与 1/2/5 倍速控制在**独立 QA 窗口**；偏好存在 user://qa_settings.cfg，游戏启动读取 speed。不能沿用旧 README 的“游戏右上角 1/2 倍速”描述。
- QA 可输入/浏览总表路径，记住路径与上次操作结果；新增“拆分／同步 Excel”与“打开分表目录”。“读取配置”改为增量读取 config_excel 分表，显示变更表名或无变化；按钮任务期间互斥禁用。后台 Thread 运行 Python，完成后“重启游戏”重载当前场景，不热切换 BattleGame。数据来源、覆盖关系和缓存规则仅见 [DATA](../DATA.md) 的分表与增量配置。
- 游戏与 QA 共用一个 Godot 进程，QA 是根节点下 QATools 原生 Window；main.show_qa_tools 复用已有面板，headless/capture 不自动创建。单独QA宿主/场景/启动脚本已由外部开发流程移除。
- config_panel.game_scene 获取 current_scene，send_control 直接修改其 game.paused/speed；restart_game 先结算保存，reload_game 调用 reload_current_scene，QA 实例保留。关闭 QA 只隐藏，关闭游戏结束整个进程。无现行进程间通信；旧 IPC 文件若留在缓存不代表仍在使用。保存失败边界见 U-008。
- 舰船/UI及音效仍为程序生成，main._draw/draw_ship/beep 为入口；2026-09-14 按用户要求新增 assets/weapons 三种透明弹体素材（光束/金属弹丸/带尾翼导弹），PROJECTILE_TEXTURES 按归一化武器键匹配敌我弹体并按 direction 旋转；不改变伤害或索敌。素材及生成提示词见 assets/weapons/README.md。preview 图片仅供历史对照。

验证路由：游戏按钮用 `tests/test_game.gd`；QA 导入/同进程场景重载为 `tests/test_config_panel.gd`。后者会临时改运行 JSON 并显示窗口，必须复制项目及隔离目录后运行，见 VALIDATION；本次11项集成检查通过，视觉布局没有另做验收。
