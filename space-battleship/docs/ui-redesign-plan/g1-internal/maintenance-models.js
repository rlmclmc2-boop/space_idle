/* Session/SaveFiles response fixtures; no files are read, written or recovered here. */
window.MaintenanceModels={
 saveStates:{saved:{title:'最近进度已写入',description:'14:32 · 已持久化版本 41 · 当前无未保存进度'},dirty:{title:'有未保存进度',description:'最近持久化14:32；此后变化尚未写入'},queued:{title:'保存已排队',description:'请求已接受；磁盘写入尚未完成'},writing:{title:'正在写入',description:'持久化版本42处理中；旧有效文件仍保留'},failed:{title:'保存失败 · 有未保存进度',description:'磁盘空间不足。旧有效文件保留，可重试或换目录。'},recovery:{title:'恢复暂停',description:'主文件无效；等待选择有效备份。未创建新档或覆盖原文件。'}},
 reforge:{clear:['强化碎片、四种专用材料、究极核心清零','普通槽位/配装、科研、反应炉、强化/历史/分支重置','超空间本轮能源、任务、材料、挂设成长等本轮字段重置'],keep:['铁、铀与时空微粒余额','船员等级/经验与有效岗位；重新核对占用','星球探索与建筑、旧征服状态','星系建设/进度与超空间路线最佳记录'],gain:['本星球标记征服，永久Buff生效','首次星球：装备有效等级+35，免费充能+10%、强化有效等级+1、幸运+100','保留无人机封存至所属星球门槛；仓库/保留容量各+10','新起点第5关；重建全新战场']},
 tutorials:{equip:['配装','选择槽位与候选后确认换装；等级保留，冷却按槽位判断。'],upgrade:['升级','查看本次实际费用和数量后购级；资源不足不扣款。'],pickup:['拾取','点击资源光点或等待自动领取；金额以对应结算规则为准。'],retreat:['撤退与驻守','盾甲耗尽自动撤退；撤退结束恢复当前装备防御。'],clear:['通关','终波结算后查看解锁，继续入口仅释放引导暂停。']}
};
