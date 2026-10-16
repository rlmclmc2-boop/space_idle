# 当前生产 DLL 的五套完整画面回退核查

基准 `f578e4a26d88709690a31cba2ef85edd9cedd670`；候选 `26b20c31efd734041bc4d5d8e50ea361fe431077`。main 精确 Git 归档；候选只应用项目 diff，5 个变更文件的 Git blob 已逐项匹配。

`tools/play_main.py` 在基准提交要求生产 DLL SHA-256 `dccd40b52e086444edd7291d2bead736b96f7876a53f989df5549a1d4f99b30a`。两侧均使用该 DLL。旧报告使用 2cf90eda DLL，已撤回，不参与本次结论。

既定五套高负载夹具。每套串行 main、候选、main；240 预热逻辑步、480 测量逻辑步，1 倍/60 Hz、FPS 0、VSync 0、完整 GL 画面、stat cache 开、保存关。

| 夹具 | main 首次 | 候选 | main 末次 | 候选减两端均值 | 候选 p95 | CPU 忙碌率（首/候/末） |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| mixed | 7.732ms | 7.694ms | 7.784ms | -0.064ms | 11.014ms | 14.2% / 11.3% / 11.8% |
| laser | 5.728ms | 5.634ms | 5.661ms | -0.061ms | 8.843ms | 11.5% / 11.0% / 12.0% |
| cannon | 7.383ms | 7.449ms | 7.390ms | +0.062ms | 11.288ms | 11.0% / 11.7% / 11.2% |
| missile | 6.947ms | 7.474ms | 7.028ms | +0.487ms | 10.624ms | 10.9% / 21.1% / 10.6% |
| longLaser | 8.862ms | 8.860ms | 8.698ms | +0.080ms | 13.322ms | 18.6% / 11.6% / 10.5% |

15/15 运行成功；每次 240/480 逻辑步、实际 1 倍、焦点正常、native 接纳、整帧相位闭合、样本数一致。每套三次的夹具、运行配置、fires、hits、事件与压力计数相同。截图显示正常战场和装备页，敌情页隐藏。

mixed、laser、cannon、longLaser 差值在 ±0.080ms 内。missile 候选高 0.487ms，但系统 CPU 忙碌率为 21.1%，两端为 10.9%/10.6%；该组受背景负载干扰，保留疑点，不据此判定稳定回退或零开销。未新增其他矩阵或独立复测。

longLaser 候选 p95 为 13.322ms，cannon 候选 p95 为 11.288ms；不能宣称所有帧低于 10ms。正常开关缓存行为沿候选定点 `test/evidence/ui-followup-20261017/INTEL_POLISH.md`，不把定点计数当五套性能数据。

驱动 `789154ddaba074cdcad6a75c9e721d93f5fc3bafa4ea5f2685929d3fd0ab331c`；mixed 夹具 `cc310aec9fddeb6b2199c811e47ff2eb4ddd82c108c381407d3c91dd13194db4`；四武器夹具 `227f9cc6bba709ba29a41041c01eab3d4064e58cdc1fc23b0f4fb92e31cb9dfe`；DLL `dccd40b52e086444edd7291d2bead736b96f7876a53f989df5549a1d4f99b30a`；Godot `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`。各次压缩原始帧、系统负载、日志、截图及哈希见 `summary-lite.json`。

仅使用隔离 D 目录，未用玩家存档。
