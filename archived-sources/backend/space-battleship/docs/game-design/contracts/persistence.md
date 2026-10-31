# 档案/通知/设置前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 档案/通知/设置：archive_panel、notifications_panel、main | Battle `enemy_intelligence/statistics`；教程completed；Notifications `entries/unread`；PlayerSettings及SaveFiles原状态口 | Notifications `mark_seen/mark_read`；main中导入/新游戏/重铸预览、确认与取消；设置与保存协调 | Notifications `changed`；保存通过现有poll/状态读取。主线反馈没有候选的完整重显/持续摘要修正 | 路径、导入来源、待确认摘要、展开、焦点与错误呈现；候选Session、文件备份/恢复与保存事务仍由原所有者控制。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 设置/危险确认 | 统一反馈重显；导入/新游戏/重铸的持续预览区域及来源变化/取消清除 | 主线尚无该修正；完整真实保存故障、恢复和危险事务实操仍需覆盖。持久预览不能只靠六秒吐司。 |

## 剩余待审：保存宿主最小结构化透传

[最小提案与固定源码核对](../../verification/m10-persistence-readonly-proposal.md)仅本地文档、未批准、未实施；复用现有SaveFiles状态与危险事务，区分纯读取、显式候选准备、内存替换及实际持久完成。不以本文授权保存/UI改动或完整V10验收。
