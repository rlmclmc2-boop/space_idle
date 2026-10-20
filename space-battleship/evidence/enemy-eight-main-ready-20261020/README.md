# 八舰静态资产合并交付

基准 main `5b3eb6b6181b31b1fd2612091dfdbb4d7b4a33d3`；从该 main 创建干净分支，只携入17758327最终确认内容，**不要合并旧 art/enemy-base-eight-static 或 art/reactive-refined-import-20261020 的整条历史**。

保留：8张确认PNG（与17758327逐字节一致）、原始atlas和父确认reactive细化源图/归一化生成器、8个texture路径、90.4×79.333逻辑舰体等比显示上限、相同上限下的现有外圈绘制适配、按实际舰体及外圈定位的血盾条、retained/canonical绘制尺寸一致。静态贴图没有内置武器；现有独立武器挂接不变。

排除：enemy_grid_layout.gd整套多格分配/回溯/overflow回退、size>=4→2×2精英推断、leader→3×2占位、新grid目标坐标/入场距离限制、Main与native authority/view及runtime间grid_plan传递、旧网格实验QA/审计/证据和中间美术稿。main原有的数值size及其既有样式逻辑保留，不把它改作精英身份。精英/BOSS美术不在本次范围。

`merge-scope.json`核对game、fixed layout、geometry authority/view、runtime、identity文件逐字节等于main；所有数值配置不变，ship_weapon_visuals仅8个texture字段改变，geometry_texture及原图逐字节保留。没有角色移动、容量、血盾/伤害数值修改。

实际场景证据：`base-eight-battle.png` 原窗口1372×883；`base-eight-battle-large.png` 原窗口1952×1256。顺序为第一排scout/sentry/interceptor/swarm/anchor，第二排reactive/shielded/command。无网格/舰名绘制，无裁剪拼图。关闭存档、QA保持血量，实际开火命中后暂停并清理瞬时弹道/浮字用于观察；不是自然关卡配置。八舰fixture覆盖size1..6，仍同样的舰体显示上限；没有按size分配精英占位。

验证：资产alpha/比例/组件/配置/原中心几何检查通过。main原版3份绘制脚本与候选版本跑同一夹具，main-reference.json和battle.json的8舰最终显示坐标逐项完全一致，8舰model width也一致。main原有的纵坐标投影保留（逻辑254→显示270.9123），不以逻辑坐标代替显示基准。原版参考30项、候选54项检查均0失败；候选实际18次我方/88次敌方开火、115次命中，alpha中心误差<0.000004。覆盖等比显示上限、retained/canonical尺寸一致、原版敌舰位置、六档fallback原显示、native不可变view中的显示尺寸。Linux Godot4.6.3 llvmpipe/GDS；native view桥接是函数级验证，没有声称Windows/native整场或性能验收。

复现：python test/check_enemy_base_eight_assets.py；把test/test_enemy_base_eight_battle.gd复制到隔离工程res://，图形模式运行，ENEMY_BASE_OUTPUT指定test/work本次目录。ENEMY_BASE_REFERENCE可指向main-reference.json进行坐标对照；ENEMY_BASE_BASELINE=1用于同夹具原main显示脚本参考运行。无攻击/共享效果逻辑修改，不扩大到武器组合/性能/全量测试。

父审后仅合并本干净分支的独立提交；本线程未推main。编队重设计继续暂停。无执行阻塞。
