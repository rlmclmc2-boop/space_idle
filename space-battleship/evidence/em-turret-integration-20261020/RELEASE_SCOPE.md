# 正式炮台接入：精确候选范围

**候选 `24f0751d`，分支 `art/em-turret-runtime-20261020`，直接基于 `108080a7`。18个文件：15个运行必需文件 + 3个必要回归文件。**

被否决的43文件 `32101f46` 未合入，也不是此候选祖先；main未更新。此候选不带设计源稿、QA renderer、截图、报告或导入中间材料。运行所需坐标/覆盖/轴心收进现有配置，未因文件数删除运行依赖。

## 逐项清单与用途

- `space-battleship/assets/ships/enemy/elite_boss_20261020/anchor-boss.png`：anchor-boss档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/anchor-elite.png`：anchor-elite档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/command-boss.png`：command-boss档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/command-elite.png`：command-elite档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/reactive-boss.png`：reactive-boss档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/reactive-elite.png`：reactive-elite档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/shielded-boss.png`：shielded-boss档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/ships/enemy/elite_boss_20261020/shielded-elite.png`：shielded-elite档位的最终静态舰体；固定承载底座烘焙其中，不包含旋转炮机。8张舰图缺一则对应档位无承载舰体。
- `space-battleship/assets/weapons/integrated_ranked_20261020/cannon-rotating.png`：最终51aae1ac独立旋转炮机，透明底；与707981f3最终PNG逐字节相同，不重复绘制底座。
- `space-battleship/data/ship_weapon_visuals.json`：登记8个档位舰体、显示尺寸、24个烘焙底座中心/07覆盖宽度，以及独立炮图轴心/可视孔口；普通行、active hardpoints/slot_map及武器profile保持原值。
- `space-battleship/scripts/battlefield.gd`：仅令hostile可视闪光/光束从炮图凹孔发出；_numeric_launch_origin与数值发射提供者不变。
- `space-battleship/scripts/enemy_rotating_art.gd`：28行纯显示适配器，将现有组件映射到烘焙底座并绘制独立PNG；不增装备，不写profile，不改模拟端口；超出底座容量或不支持的武器沿用旧画法。
- `space-battleship/scripts/enemy_visual_identity.gd`：仅依发布tier/leader挑选8个变体，缺失回退普通舰，不从数值size猜档位。
- `space-battleship/scripts/main.gd`：正式canonical/BOSS路径接入同一炮图，并读取批准的变体显示尺寸。
- `space-battleship/scripts/retained_enemy_contacts.gd`：正式retained精英路径接入同一贴图、轴心、旋转和尺度；普通舰继续原画法。
- `test/check_enemy_base_eight_assets.py`：适配原八普通舰冻结检查，只排除另有严格检查的新变体/metadata；保留原alpha、比例、连通块、普通配置及几何覆盖。
- `test/check_enemy_runtime_art.py`：严格检查9张批准PNG哈希、尺寸/透明、24个批准挂点、8行active契约、普通配置及中心几何字节。
- `test/test_enemy_runtime_art.gd`：正式main.tscn回归夹具，保留tier/leader/size/回退覆盖并验证真实装备数值、canonical/retained/native视图、孔口、轴心及实际转向；不注入QA renderer或替换组件profile。

## 必要验收

- 在正式 `main.tscn` 上执行本任务夹具，279检查、0失败，31次实际开火、40次命中。普通识别renderer未注入QA替身；精英走retained，BOSS走canonical；另检查native显示视图的轴心与canonical一致。
- 8张正常窗口图 + 左右实际瞄准两帧，1372×883，均已逐张核看；转向约+27.4°/-27.4°，轴心不移。没有新增设计或独立复测线程。
- 四种实际表记录270005–270008均为1件武器，实际组件仍1个；精英2个/BOSS4个是烘焙底座数量，未为填空增添武器。护盾舰仍laser_mon，其他仍cannon-mon；actor size、dmgMultiple保留表值。
- `python test/check_enemy_runtime_art.py`、`python test/check_enemy_base_eight_assets.py` 均PASS；9 PNG批准哈希、24挂点07覆盖、active hardpoints/slot_map/profile、普通配置和旧几何全部通过。
- Godot 4.6.3导入/脚本检查无解析错误；`git diff --check`通过。game.gd、simulation_geometry_authority.gd、native_execution_session.gd、game_data.json与108080a7字节相同；没有Excel/数值/保存改动。
- 最终夹具运行前关闭场景已有session，用GDS实际战斗隔离验收；独立native显示view另作同夹具数学检查。未宣称native整场/性能验收。为摆位冻结血量、发布tier/位置并移动显示瞄准锚点，仅在夹具中；隔离XDG目录，禁存档。

## 证据与复现

- 本原任务分支 `art/cannon-redesign-20261020` 的 `runtime/` 下保存10张原窗口PNG、runtime.json、run.log；不进入18文件候选。早先932项2/4炮QA结果留存为设计记录，不作为正式接入证明。
- 复现使用候选分支的 `test/test_enemy_runtime_art.gd`，启动项目为候选的 `space-battleship`，`RUNTIME_ART_OUTPUT`指定隔离输出并设置隔离XDG数据/配置/缓存目录；图形命令使用Godot gl_compatibility与Dummy audio。
- main仍108080a7。等待父审候选；本线程不合main。
