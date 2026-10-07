# 真实传输路径补证

父源码审查发现52b4122的实际遗漏：save_transfer.schema未列hyperspaceReceipt，clean会剔除该字段；原44项只走portable_save_data到load_progress_data，不能证明导入导出。此前通过表述撤回，并修正README。

实现只在现有schema增加round:i、run:i、drone_id:s、unread:b四字段，不改变shape、clean、奖励结算或其他数据校验。

反馈专项53/0：实际export_progress写文件、prepare读取和清洗后加载，分别确认未读标记／已读标记；旧档prepare_data不造标记、加载安静；已知字段类型非法仍format拒绝；负整数符合原i形状策略但UI加载语义校验令其安静；子项未知字段仍剔除。原保存传输专项58/0，包含实际commit_import备份／安装／启动加载保留标记，以及原有非法数据拒绝、失败回滚、未知元数据剔除等断言。均headless，不冒称本次图形或普通玩家导入操作通过。

一次失败来自JSON解析后的整数值为float，原始字典对整型字典比较失败，而加载后已一致。改为先保持既有i形状校验，再按完全相等的整数值与字符串／布尔逐项核对；没有删校验、没有容差。原始日志见两份transfer-*-headless.txt。

保存传输事务使用独立transfer-fix-transaction-data XDG，反馈使用transfer-fix-data；没有触碰原存档或原阶段检查点。父仍应验收实际领取、跨页和重开体验；父尚未整合52时应按52b4122再本补丁顺序取。
