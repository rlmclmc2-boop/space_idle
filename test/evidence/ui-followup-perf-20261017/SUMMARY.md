# 三项 UI 候选五套完整画面回退核查

基准 `f578e4a26d88709690a31cba2ef85edd9cedd670`；候选 `26b20c31efd734041bc4d5d8e50ea361fe431077`。main 精确 Git 归档，候选只应用两提交间项目 diff；5 个变更文件的 Git blob 已逐项匹配。

沿既定 `five-environment-20261015/baseline` 驱动和 mixed/四种武器夹具。每套顺序 main、候选、main；240 预热逻辑步、480 测量逻辑步，1 倍/60 Hz、FPS 0、VSync 0、完整 GL 画面、stat cache 开、保存关、同一 DLL。

| 夹具 | main 首次 | 候选 | main 末次 | 候选减两端均值 | 候选 p95 | CPU 忙碌率（首/候/末） |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| mixed | 7.447ms | 7.454ms | 7.496ms | -0.018ms | 11.167ms | 12.8% / 12.8% / 13.4% |
| laser | 6.030ms | 5.933ms | 5.904ms | -0.033ms | 9.497ms | 13.3% / 11.0% / 11.6% |
| cannon | 5.909ms | 5.958ms | 5.915ms | +0.045ms | 8.930ms | 11.7% / 12.2% / 11.7% |
| missile | 6.488ms | 6.689ms | 6.425ms | +0.232ms | 9.584ms | 12.0% / 11.2% / 11.1% |
| longLaser | 8.969ms | 8.941ms | 8.792ms | +0.060ms | 13.374ms | 11.0% / 10.8% / 11.6% |

15/15 运行成功；每次 240/480 逻辑步、实际 1 倍、焦点正常、native 接纳、整帧相位闭合、样本数一致。每套三次的夹具配置、fires、hits、事件计数与压力计数相同。所有截图显示正常战场和装备页，敌情页隐藏。

mixed、laser、cannon、longLaser 的差值在 ±0.060ms 内；missile 候选比两端均值高 0.232ms（约 3.6%），p95 为 9.584ms。这一组有轻微回退迹象；单次夹逼不足以断言稳定回退或零开销。longLaser 候选 p95 为 13.374ms；不得宣称所有帧低于 10ms。

正常打开/关闭后的缓存计数沿候选定点 `test/evidence/ui-followup-20261017/INTEL_POLISH.md`：10 项通过。此次高负载跑的是默认隐藏页，不把该定点计数充作五套性能数据。

驱动 SHA-256 `789154ddaba074cdcad6a75c9e721d93f5fc3bafa4ea5f2685929d3fd0ab331c`；mixed 夹具 `cc310aec9fddeb6b2199c811e47ff2eb4ddd82c108c381407d3c91dd13194db4`；四武器夹具 `227f9cc6bba709ba29a41041c01eab3d4064e58cdc1fc23b0f4fb92e31cb9dfe`；DLL `2cf90edabbb55576b1e99027889c708007e51df87861caf3c03bbdddcecae96a`；Godot `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`。各次压缩原始帧、系统负载、日志、截图及哈希见 `summary-lite.json`。

运行态仅写隔离的 D:/CodexBuild/space_idle/ui-perf-20261017；未用玩家存档。
