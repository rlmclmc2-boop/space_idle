# 最终源码同版大小舰补图

固定运行源码 **5b4f72331038622ce739578fcdf3823a0a0b4716**；取图时分支HEAD为证据提交6cebf6d8，运行代码与5b逐字节一致。本次没有修改代码/配置/素材，也没有重跑交易或整套回归，只补以下两张真实Godot 4.7.2整屏，已实际查看：

- [01-new-session-frigate.png](01-new-session-frigate.png)：全新独立/tmp设置与存档目录，默认新局Frigate、默认配装/付费等级1、钱包0，user暂停后直接取图；没有改进度/钱包/装备。自动跳过教程为独立取图设置，未改玩家设置。
- [02-cruiser-comparison.png](02-cruiser-comparison.png)：沿既有Cruiser比较预览状态，经Campaign/Equipment/Economy受控restore及真实native refit，最高进度100、cleared1–99；脉冲炮槽19级、其他槽18级，2,000,000铁/1,000铀/2,000简并物质。实际点击当前武器1及舰炮候选，仅浏览比较，现装仍为脉冲炮；没有购买或提交候选安装。受控状态不冒充自然赚取进度或个人存档。

两张都是根视口1440×900原像素PNG，未裁切、缩放、拼接。原始状态/来源 [screens.json](screens.json)、取图驱动及日志在本目录；[manifest.json](manifest.json)将原始runtime source_hashes逐项核对固定Git源码/素材，并列每个交付文件SHA256。本次输出 `SAME_VERSION_SCREENS_COMPLETE failures=0 images=2` 仅指启动、受控准备与候选浏览核对，不是新一轮完整正确性/视觉验收。

与既有同源码Heavy [武3](../evidence/selected-weapon-2.png)、[武5](../evidence/selected-weapon-4.png)及其余逐槽图组成同版大小舰交付。根审已实际查看6ce武3/武5并确认窄修可关闭，原独审收尾；原b935关联两项已确认改善，本次不重开布局或扩大验收范围。原证据与缓存保留，未合main，之后等待用户视觉验收，不自行启动新批。执行者未实际上下文压缩，无环境/审批阻塞。
