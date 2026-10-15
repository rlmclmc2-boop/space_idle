# 10关背景候选接入：真实主场景与资源驻留

本批在表现分支接入父已审7e7fddf0候选。生产代码仅把battlefield.gd的OPENING_SCENERY常量扩为10张预加载纹理，并添加stage_03–10.png。首两张PNG字节未改；既有shader、按stage切换绑定、按distance/length取景的逻辑均未改。没有修改时间、距离、关卡/战点、敌人、数值、奖励、解锁或新舰绑定。

## 真实画面证据

- transition-2-end / transition-3-start、transition-5-end / transition-6-start、transition-9-end / transition-10-start.png：真正main.tscn的关界前后完整UI。
- transition-2-3 / transition-5-6 / transition-9-10.mp4：主场景原有清场倒计时到下一关的连续输出，60Hz逻辑、每6步采样一次，视频10fps。没有在视频中插入静态舰体、假弹道或背景淡黑切镜。
- combat-3/6/7/10.mp4及对应t012/t060/t120.png：现有战点、现有舰体、默认装备、正常武器/敌人更新的短段实战。6关样本右侧小舰实际覆盖月面；7关记录月面段和真实撤退；10关样本实际覆盖节点暖光。

这是隔离用户目录中的短帧夹具，不是从新档长时间打到第10关：通过现有checkpoint恢复API进入指定关末LEVEL_CLEAR和现有倒数第二个战点COMBAT。临时profile仅开放访问10关并关闭保存，不改变装备等级、伤害、血量、敌人组或数量。默认低级装备在高关会迅速撤退，录像保留该结果，未提高属性或造伤害事件。每个战斗样本新建临时主场景，避免上一场提示残留。

当前分支尚未接Sol的新版敌人/数值表，画面遭遇数是该分支原有配置，不能把这批截图解释为新版18点平衡已落地。样本截图中的FPS来自软件渲染与逐帧截图夹具，不作性能数据。

## 驻留和加载路径

texture_probe.gd在空主窗口中逐张持有10个Texture2D引用，读取RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED：

- 基线9,720,771 bytes；全部加载后43,176,207 bytes。
- 10张背景计数增量33,455,436 bytes，约31.91MiB；原RGBA8等价估算33,464,288 bytes。两者分别记录，不将估算伪称驱动物理分配。
- 保持引用后的30帧，计数43,176,207→43,176,207，无增长。
- 主场景三次自动换关及四段交火后，10张背景RID保持一致。生产帧循环没有load、纹理创建或上传；stage变化只绑定预加载引用，distance变化只更新既有UV参数。
- 观察导入为lossless mode=0、mipmap=false、size_limit=0，shader维持linear/repeat_disable。没有新增渲染pass、实时3D、后台加载架构或敌人扫描。

上述是Godot4.6.3 GL Compatibility/Mesa llvmpipe本机纹理计数，**不等于Windows驱动物理显存测量或原生帧时验收**。本批未占用Sol窗口、未开展额外优化探索。Windows原生完整帧/忙帧/尾部检查仍按父协调安排。

## 验证与复现

runtime-validation.json记录自动换关时刻、实际战点位置、敌人数、弹体峰值、最终状态和RID。screenshot函数在每次绘制前后核对敌人、弹体、距离、RNG不被绘制改变；正常推进只来自scene._process(1/60)。texture-residency.json保存逐张加载计数。integration-manifest.json保存运行/候选哈希和导入参数。

capture_runtime.gd和texture_probe.gd在隔离导入工程及XDG用户目录运行，OPENING_REVIEW_DIR指向本目录。生产资源不依赖这些夹具。主场景验证为软件兼容路径；不冒充Windows原生实战性能通过。正式美术动态可读性仍供父从Git回读视频审查。
