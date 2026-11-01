# 档案/通知/设置前后端契约

[唯一入口](../README.md) · [共同读取/接纳协议](../14-ui-contracts.md)。本页维护本模块公开接口；当前实现和消费源见[11](../11-stage6-contract.md)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 档案/通知/设置：archive_panel、notifications_panel、main | Battle `enemy_intelligence/statistics`；教程completed；Notifications `entries/unread`；PlayerSettings及SaveFiles原状态口 | Notifications `mark_seen/mark_read`；main中导入/新游戏/重铸预览、确认与取消；设置与保存协调 | Notifications `changed`；保存通过现有poll/状态读取。主线反馈没有候选的完整重显/持续摘要修正 | 路径、导入来源、待确认摘要、展开、焦点与错误呈现；候选Session、文件备份/恢复与保存事务仍由原所有者控制。 |


## 剩余待审：保存宿主最小结构化透传

当前结构化只读透传仍是未实施的接口缺口，尚需原负责者定向审查；复用现有SaveFiles状态与危险事务，区分纯读取、显式候选准备、内存替换及实际持久完成。不以本文授权保存/UI改动或完整V10验收。
