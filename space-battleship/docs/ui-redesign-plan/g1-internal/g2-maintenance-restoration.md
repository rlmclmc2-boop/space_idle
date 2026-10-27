# G2 保存、危险事务与档案实物

实际新增工作点：保存状态台与请求/写入/持久完成区分；候选目录和当前目录分列；目录选择、请求保存、备份/导入入口；音乐/音效、伤害数字all/critical/off、0–86400现实秒自动保存间隔及跳过引导。保存失败/恢复暂停在战场持续保留同一入口，不依赖吐司。

重铸/导入/新游戏各有子路由、当前对象、持续预览、取消、确认和独立结果。重铸按03§7列出真实重置/保留矩阵：星球探索、建筑、星系保留；没有误列清除。星球选择、保留无人机、文件来源、目标目录及清个人设置变化使预览失效。船坞未领取阻止重铸。导入有效来源响应与非法来源响应分开；结果示例明确“内存会话替换、持久化待重试”，不把请求接纳当保存成功。所有结果只是浏览器响应样本，未实际操作文件或新建GameSession。

档案：飞行手册按条目回看，已实践状态保留；首次引导有继续，释放guide原因不改变user暂停。敌情选择与同来源舰体缩略图、盾甲、机制；通知按稳定key分别mark_seen/mark_read；统计按来源分盾/甲，禁止另消费伤害回执。当前敌情/统计仍为显式样本，需Battle现有查询绑定，不证明实际交战数据。已见不减未读，已读减少未读；该差异已浏览器核对。

## Godot还原与所有权

| 对象 | UI树/选择记忆 | 实际提供方与接纳 |
|---|---|---|
| 保存 | SettingsPage/PersistenceStatus/DirectoryDraft/动作；BattleStatus中同一持久错误入口 | SaveFiles既有poll/状态；request_save的ok只排队，saved(generation,changeNumber)才反映持久完成，较新的dirty不能被旧完成清掉。main现行保存协调，UI不得读写磁盘伪造成功 |
| 目录/偏好 | FileDialog候选路径、当前路径、偏好Controls；失败恢复当前值并保留错误 | main现行configure、PlayerSettings.save_change/save_interval/save_auto_skip_tutorial；本批只设计，不写个人设置文件 |
| 危险事务 | DangerPage各子路由；source/planet/retained/clearSettings快照与展示预览绑定，确认按钮仅对当前有效快照开放 | main现行preview/confirm/import_candidate/prepare_reforge。真实候选Session、备份/校验、替换和写盘状态属于main/Session/SaveFiles，UI不能仿造事务或复用失效候选 |
| 手册/通知 | ArchivePage中独立tab、selected tutorial/敌id/通知key；详细与操作不互相丢上下文 | tutorial.completed，现行引导暂停原因；Notifications.entries/unread/mark_seen/mark_read及changed；mark_read不隐含mark_seen |
| 敌情/统计 | 同visual_key的预览纹理、当前敌情详情、统计表 | Battle.enemy_intelligence/statistics，敌消失清除旧详情，不用列表下标当身份；同视觉映射来自当前舰体资源。BattleView仍是唯一伤害回执消费方 |

尚未完成：真实存档故障/备份恢复各分支、旧版本拒绝实机、重铸完整会话/封存重建、音效实际开关、目录平台差异、首次解锁引导全过程和对象消失清理。浏览器只覆盖错误持续显示、排队不冒充完成、预览失效/取消、重铸保留矩阵、导入内存/写盘结果分列、通知与引导暂停独立，不据此通过V10。

当前额外端口需求优先复用既有main预览/结果和SaveFiles状态；如现有结果只有message，需原线程确定保存阶段/dirty/last-success/error、候选摘要与实际替换/写盘结果的最小结构化只读截面，不把前端示例字段反向指定为新业务协议。
