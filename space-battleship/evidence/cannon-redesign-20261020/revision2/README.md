# 当前宽炮管候选

基线：7b081cee未验收版。原尺寸前后对比见[上级入口](../README.md)及[并排原图](../compare.html)。本目录为最新八版及±35度转向图，全部1372×883原窗口PNG。

独立炮贴图改为单块浅色壳体、宽深色炮管和连续钢灰方向面；没有小面板、细刻线、侧翼或第二个底座。炮身独立等比缩放到暗凹槽宽的110%，八舰体PNG、24固定底座坐标、舰体展示尺寸及中心判定均与7b081cee一致。固定底座肩部承载检查保持通过。

932检查0失败，41次开火/53次命中。新增原窗口轮廓检查：炮壳13.49–17.18像素宽，炮管5.07–6.46像素宽；最小阈值分别13/5像素。原有轴心/炮口精确对齐、0/±55度框内、枪壳不互叠、血盾/标题预留检查通过。±35度仅炮身附近像素变化，固定底座不旋转。ranked.json保存逐舰逐炮测量；summary.json保存冻结检查、最小/最大像素和转向差异；asset-check.json保存来源/alpha/哈希/接口检查；run.log保存实际图形运行日志。

和7b081cee比较，八舰体PNG逐字节一致，舰体manifest移除独立gun字段后完全相同；ship_weapon_visuals.json仅movable_gun.housing_to_well_ratio从0.9变为1.1，所有24静态底座坐标均未改。生产scripts、game_data和config_excel未改。数值1/2/4仍只接口，2/4配装仅在关闭存档的隔离夹具内安装。Linux Godot4.6.3隔离GDS验证，不含native整场/性能验收。无执行阻塞，候选未合main，外观待主审。

复现：导入器python space-battleship/art_sources/enemy-fleet-20261019/prepare_ranked_assets.py；ENEMY_RANKED_EVIDENCE指定本目录后运行python test/check_enemy_ranked_assets.py；test/test_enemy_ranked_art.gd复制到隔离工程res://，用独立XDG用户目录及RANKED_OUTPUT运行图形Godot场景。原生成PNG保留在/workspace/generated_images/exec-84a5bfdb-68d5-48a0-bd9c-f3b86d0efb78.png。
