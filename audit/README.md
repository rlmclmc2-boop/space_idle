# 两本异空间工作簿：可直接制表的数据交付

冻结源码 f9d31b92d2b80af1c4b663173f12e4f6a23b8841。此批仅契约和现值数据，不修改生产代码，不制作XLSX，不运行Godot。

**父制表脚本直接读取 AUTHORING_PACKAGE.json**：`workbooks[].filename` → `sheets[].name/columns/rows`。columns每列含key、description、type、unit、constraint、editable；rows为保留int/float/bool/null/string的数组。readonly整页及readonly_rows锁定行可直接使用；未锁定行也必须按列editable保护结构列。行1字段名，行2说明/单位/约束，行3类型，行4起现值。空字符串和null须按字段类型区分；拒绝公式。

TWO_WORKBOOK_CONTRACT.json为正式逐列和映射契约；WORKBOOK_CURRENT_ROWS.json是分离三行元信息的同内容布局。SHEET_COLUMN_CONTRACT及STRUCTURE_DRAFT是早期逻辑草案，**以TWO_WORKBOOK_CONTRACT及AUTHORING_PACKAGE为准**。奖励参考整页只读，早期inventory的可编辑标记已修正，不更改catalog。

hyperspace_config.xlsx共13页，hyperspace_enemies.xlsx共7页。基础参数40行包含37个既有标量与3个新增默认值：现代化起始系数1、自动时间船员基数100、自动票耗船员基数20。既有amplification_start_level=4拟接线，单位无人机等级，当前冻结实现仍固定4；默认没有平衡改动。

奖励成员分配285行：200个预算块分配，加85个零预算成员占位行。零预算的order与reference_member_ordinal都为空；仍保留member_order/slot，导出ordinal=[]及jewelDropRolls=0。不能丢掉这些实际成员，不能虚构其预算。

order固定、0起、按作用域唯一连续，物理排序不得改变字典或数组及RNG调用顺序。稳定实体ID、局部参数首键、操作资源次序、原15槽索引均保留。元信息文字不能绕过真实校验。主体JSON元信息和非可调派生投影需要明确锁定模板；不能将旧JSON数值作为第二个可写权威。

导入阶段1计划输出config/candidates/routes/recipes四JSON。catalog和1960 sources两JSON按契约SHA只读校验，不重写；原设计组来源尚缺主线生成元信息，不能声称已可完全重生成。无旧档迁移。

验证：338个配置叶值的52根字段回写全部相同，只追加3个新默认键；敌人、编队、路线、奖励recipes在原物理行和打乱物理行两种布局中投影完全相同，字典顺序相同。AUTHORING_ROWS_VALIDATION.json记录结果。配置全页打乱测试待正式导入器实施，不能冒充已完成。

已吸收独立12ed3f8的九组关键说明纠正；单位含加成比例(+200%=×3)、直接倍率、游戏秒、批次数/层数、统御归一化、究极覆盖、首挂设仅解锁、相对权重；溢出10格锁定。

下一步父用正式spreadsheet工具制表并确认契约；随后此线程接入导入器/业务校验/正常启动拒绝无效包/四输出事务及共享结算UI公式。现有atomic_batch只承诺普通写失败回滚，不声称进程死亡时四文件原子。
