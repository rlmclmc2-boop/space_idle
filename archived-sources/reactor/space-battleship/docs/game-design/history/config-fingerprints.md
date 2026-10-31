# 原09输入指纹与旧副本核对（历史记录）

[唯一入口](../README.md)。仅供追溯原09读取对象，不作为当前输入指纹、工具入口或待恢复数据。

## 5. 基线输入指纹

用于审阅确认此次读取对象，不是新的配置权威。

| 工作簿 | SHA-256 |
|---|---|
| ai_tech_tree.xlsx | b70ef7f68e1f1ea241b0b28aa9256382b359fff99ed82968cd9c6436c5ed93df |
| battle_design.xlsx | 78421091f12082cf5ef4a12b7c9f971a2e273d84dddafa5571453b608de1bf1b |
| config.xlsx | b7ef041db8912c64f9c52a7fb0698dd63ac0e5dbc89ab31f0d552fafd6e9b192 |
| crew.xlsx | a3b391374038cb1fb44b72d93ce2461316ee756d41307085865a771b16bcbb1d |
| crew_assignment.xlsx | 1c972db0ddacd785f683cb4bd98bc79d6f4e650035f0f1b6400a02059420d50d |
| crew_config.xlsx | 3f962042b041e8ccf85c2e841fde6fa9fe78c21d7a6536687168c1dc2fe34cef |
| enemy_weapon_base.xlsx | 27bc9c35185e5b5980371f9a05720e825ab3ffe97507a46e5b9e8c0a59f9c259 |
| enhance_config.xlsx | 4b91a1a0cd6311c0eeedf2f61fd37dc113181c4615434f5a03f66a73152f7da5 |
| equipment.xlsx | eaff9aa523a003bc32183d10d9eaf2f131e1feef75307473424144c3c08b697d |
| galaxy.xlsx | 2aa196af0a6f3ef5bb22103d48ea98db31fd880892bd83a30bb50fa3646d7d11 |
| galaxy_build.xlsx | 664c9d1f66e8753dba189c12712df925fb1a50bfc1c06f969b25ed6a0a62d1b6 |
| galaxy_config.xlsx | 199116ae33fda8a8216b0ef3fb02747b107139671cea688c22f1ce65036c5b38 |
| hightech.xlsx | b53e10c4c34cbbb73b0967aedb0e79fdfe83d3fb3357e5e2e4bcf123ba3329b9 |
| hyperspace_config.xlsx | 8c3c04ce59d35991f9261ac57039d003d2e1ac2da121210cc1521c79492104cd |
| hyperspace_enemies.xlsx | 5db22fee0de977835b4101b8689dfbf11f76b2185cde2b359a710f2371a15085 |
| level.xlsx | 202eae560214354c5a78cc2f2d042a7b292fc88b944b9580acb7d560e546f18f |
| level_monGroup_generated.xlsx | b1ed60b126b21999163f7417cb1929dd3b740480aca8bbe2d507e5c7ccf13500 |
| mon.xlsx | 204acd2961cec56282763513415d4bcf14cee40de4ea59e4a852ac3e1cf2040e |
| monGroup.xlsx | 321f2d87798e6a8374f16a47f6f24956fe5d07e58e97cc5078d5e451b0219b6b |
| planet.xlsx | 6a9758c3a6e6173b859811b3a0f46493c8bda4108cfbf30eef590c3745ad5eb8 |
| planet_buff.xlsx | bd0500698de296e0cad32dfc856401e018eada2de95ae9c6ec7bb8e6951d390b |
| planet_build.xlsx | 8e60ba32075c25955a272784f91606795abade6a632a59460ca9dae030d332ce |
| res.xlsx | 6859620d9c46434c2d580567a4bb2a3a5d50daf94a351a51cf446c0430917a61 |
| ship.xlsx | 4ac745dd23c737d110907a44f44755e1f705ede445664cc78771b1df161f7020 |
| unlock.xlsx | ee216e7524e918279a967220c1a205cfd433fe2c9c389c2a7f2a2a35525b2ed7 |
| weapon_motion.xlsx | 7a686c2f8c34e4c584f1e208525be87dc7828f37291e03432d93ffc50fb2fa5c |


## 6. 仓库根旧总表与发布副本核对

`../../../太空战舰.xlsx`是工具`tools/config_workbooks.py`的split动作默认外部总表输入，而正式incremental_import仅接受项目`config_excel`目录。总表SHA-256为`c6d04c796b203a40cc72b5b35ad818d17877f92312dedfcb74a53ccff871e026`。读取其8个sheet并按去除尾部空列/空行的单元格值比较，7个同名表全部与当前正式拆分表不同；不能无条件重新split覆盖main内容。

| 总表sheet | 有效数据行（第4行起） | 与正式根表关系 |
|---|---:|---|
| 总览 | 58（说明条目，非业务行） | split明确排除；历史玩法说明 |
| level | 70 | 不同；正式220关 |
| equipment | 503 | 不同；旧逐级行与unlock字段，正式11条基础定义 |
| mon | 6 | 不同；正式10461条 |
| monGroup | 8 | 不同；正式2330条 |
| res | 2 | 单元格值不同，不能只看行数判等 |
| config | 7 | 不同；正式有效配置38条（空行不计） |
| hightech | 3 | 不同；旧timeCost字段，正式保留4条tpCost字段 |

总览仍写导弹最多3枚且目标不足少发、按关卡距离插值倍率、终点必Boss等旧规则；当前正式Excel与代码已经是4枚发满、按战点序号插值、combatTier与终点分离。本方案从main现行运行输入建立新规则，不把历史总览恢复为新增需求。保留旧总表文件作为原始来源历史，不让它与正式拆分表同时成为权威。现行split还明确排除`crew_level`sheet；本方案不会因schema齐全性重建已删除成长表。

发布副本已经逐字节比较，均与当前正式根表完全相同：

| 发布文件 | 有效行数 | SHA-256 | 与根表 |
|---|---:|---|---|
| published/level.xlsx | 220 | 202eae560214354c5a78cc2f2d042a7b292fc88b944b9580acb7d560e546f18f | 字节一致 |
| published/mon.xlsx | 10461 | 204acd2961cec56282763513415d4bcf14cee40de4ea59e4a852ac3e1cf2040e | 字节一致 |
| published/monGroup.xlsx | 2330 | 321f2d87798e6a8374f16a47f6f24956fe5d07e58e97cc5078d5e451b0219b6b | 字节一致 |
