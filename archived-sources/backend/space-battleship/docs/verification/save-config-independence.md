# 保存配置身份解绑：实际修复与交接

用户已明确旧规范仅作参考，不保留重新引入的存档配置身份绑定。本候选实施基线`feat/amount-safe-previews@ad4c01d7fd765a20701845b8bf0effe7ae217c91`，核对main时固定`e3b38d7b6d8256f6031e1b086c7db7812b6a441f`。**仅本次必要作者验证，待根线程既有审核；未合main，不代表M10保存事务、完整游戏或UI验收。** 唯一规则入口仍为[设计README](../game-design/README.md)；规范状态由既有Astra线程同步，本页只记实际链、源码差异与证据，不抢写规范。

## 指定历史链

| 固定提交 | 定向源码事实 |
|---|---|
| a65327c25adb0d752fc5c393f77703497ab1882a | Remove configuration identity coupling from save storage：删除SaveFiles构造/读取/写入的_config_hash及configHash匹配，保checksum与payloadHash。 |
| 0822763bd9f2779dbda0faec1e3643b1bc888f0e | 重新将configHash列为必需64位hex，request重新接收并写入；其余保存边界修复不因本次回退。 |
| 9490a580d2c5c84a0f75a131d26c9f4b5930717f | Session写档计算配置文本SHA；_candidate_from_envelope在解码/构造前因指纹不同返回ConfigurationMismatch。 |
| 51d3bdf3160b4a5e5c382cdff25cb05b694b5f3d | initialize保存_configuration_hash，request_save用会话指纹，构造后又比较一次指纹；这也是本次删除的第二处拒配。 |

四对象均在原本地Git解析。核对main时Session blob=`d5f150e9c55a6245a7ec64827e66315c60ed5037`；SaveFiles blob=`36a868a56f5678bc2a89e5108f7537988907ee47`与本候选基线完全相同，绑定仍实际存在，不能把a653历史删除当现状。当前及main Session均FileAccess读取JSON Dictionary后验证配置，没有ConfigBundle加载/查询包装；main foundation/host仅validator/player_settings/save_files/state_codec四文件。validator旧注释称ConfigBundle，本次只改为configuration data，不删验证器。

## 精确源码交付与兼容

- foundation/host/save_files.gd仅改valid_envelope_shape/request：不要求、不写configHash，formatVersion仍1，旧信封含此字段直接忽略；payloadHash仍必需64位hex。正常request为payload/changeNumber/sessionId/utc四参，保可选第五legacy实参作旧调用兼容，明确忽略且无格式/匹配校验，不得据此再写身份。read_pointer的原slot checksum、generation、大小、JSON和payloadHash校验、writer/backup/原子文件替换算法均不改。
- src/game_session.gd仅删_configuration_hash字段、initialize指纹赋值、request_save第五实参及_candidate_from_envelope前后两次配置SHA匹配；直接配置读取、HyperspaceConfigContract.validate、StateCodec.unpack、模块恢复、native初始化及其他候选准入完整保留。不是“接受任意配置/任意payload”：ID/状态或配置本身不合法仍由必要有效性校验拒绝。
- foundation/host/hyperspace_config_contract.gd仅一行注释称谓，所有验证方法不变。没有改C++、通用Amount、Excel、UI或M10事务；没有读取/改写个人存档。旧含configHash档仍经原完整性校验，只是不因配置身份拒绝；读取和导入都不重写来源文件。
- 主线Session与本分支有其他差异。合并只应用上述字段/方法精确diff，保留各组新源码和UI；不能把本旧树整体覆盖main/共享候选。SaveFiles在核对main与基线同一blob，可直接定位两方法；validator仅注释。此补丁不依赖重新引入ConfigBundle或配置指纹。

旧历史探针仍有过时绑定断言：_save_files_probe要求写入configHash/拒invalid hash；_stage6_page_probe要求configHash并拒错指纹；_stage6_session_probe要求会话冻结配置指纹。这些不作为本次准则，不为让旧断言通过恢复已裁定错误的绑定；本轮未重写它们或运行无关UI/保存故障事务范围。

## 必要证据

[唯一新增定向探针](../../foundation/tests/_save_config_independence_probe.gd)27项通过，使用同一实际Session/FoundationDisk/native：新request_save及真实writer输出无configHash且保payloadHash；兼容实际autoGenRes间隔30→31的配置后能加载，候选直接消费31；两种不匹配旧configHash档均能load_candidate/import_candidate，来源slot字节不变；有效指针但坏payloadHash、坏原始checksum、缺payloadHash、错版本及非法配置仍拒绝。另核旧五参调用不构成身份gate且新写档仍无字段，其他request metadata仍校验。

main入口check-only退出0；正式[原始日志/源方法/依赖hash清单](save-config-independence-evidence/manifest.json)无ERROR/WARNING。首轮探针变量与SceneTree.root重名的解析错误已更名修正，不计正式证据；未更改生产校验来适配夹具。全部生成配置/存档/文件位于显式新建TEMP测试目录，未触及原用户文件。未宣称独立复测或审核通过，不扩大M10事务测试。M10原SHA256与179/262元数据保留；本接替尚未实际压缩。

复现沿foundation入口，设SPACE_IDLE_NATIVE_EXTENSION、SPACE_IDLE_GALAXY_PROBE_CONFIG及新的显式TEMP目录SPACE_IDLE_SAVE_TEST_DIR后，用Godot4.7.2运行`--headless --path . --log-file <临时日志> --script res://foundation/tests/_save_config_independence_probe.gd`；入口检查仍`--check-only --script res://src/main.gd`。不提交TEMP档、运行配置、DLL或缓存。
