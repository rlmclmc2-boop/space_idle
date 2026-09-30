# 存档尾延迟测量与优化候选 2（2026-09-30）

本报告保留第二轮旧保存机制的测量与隔离异步候选，指标不是当前版本结果。后续用户已明确改为仅定时/手动保存，并解除业务操作的即时写盘依赖；当前契约见 [PROJECT](docs/PROJECT.md)。未接入本轮异步候选，未重跑全量性能测试。旧候选的 [接入补丁](../test/work/saved-diagnosis-tail-promotion/integration.patch) 与 [冻结写盘器](../test/work/saved-diagnosis-tail-promotion/scripts/progress_writer.gd) 留作历史证据，勿对当前源码直接应用。

依据 [PERFORMANCE_DIAGNOSIS.md](PERFORMANCE_DIAGNOSIS.md) 与 [PERFORMANCE_OPTIMIZATION_1.md](PERFORMANCE_OPTIMIZATION_1.md)。第二轮解释了 30ms+ 单次保存：尖峰位于文件打开和替换调用，序列化没有同量级尖峰。隔离候选将普通进度文件操作移至唯一写盘线程；长跑 ordinary 主线程阻塞最大 2.672ms，即使后台出现 422ms 替换等待也未带入请求帧。但即时宝石事务遇到 477ms open；15min >33ms 数量 7→2，max 56.593→487.015ms，**总体最坏尾帧未改善，不能称为消除全部 tail latency**。下文均描述该历史候选。

## Save pipeline breakdown

使用同一第 82 关快照，SHA-256 `8b882f2774ee02c3ce63e2bc02edf51ad48e9a7c35a8d49d89103577f0280c1d`；配置 SHA-256 `7cfd9a86bde899b28820e81cad1cc5e1b8b497e2dc942fa5ee3a3d00bab51ac3` 在基线、候选和当前源码相同。种子 1701，Godot 4.7.2 Windows，1373×883，VSync 关闭，60 FPS，上述六页各预热 60 帧、测量 300 帧。2x 每帧推进两次 1/60 秒；15min 为 1x 船员页。工程、配置和 APPDATA/LOCALAPPDATA 均隔离；真实性能任务串行。保存阶段采样包含预热和长跑，帧表只计正式采样。下表单位 ms，分位数为排序后 floor(n×p) 项。

`JSON.stringify` 在引擎内部完成对象序列化与文本构造，作为 `serialize_stringify` 整体计时；UTF-8 编码单列，未人为拆分引擎黑盒。基线 `store_string` 等价的 UTF-8 转换与 `store_buffer` 被分开测量；采样未改变其同步保存边界。`copy_transform` 包含兼容字段投影，`build` 包含保存时间戳和状态整理。文件阶段是 API 墙钟耗时，不能凭此判定磁盘、文件过滤驱动或调度的具体比例。

| 阶段 | 基线 avg / P95 / P99 / max | 最终候选 avg / P95 / P99 / max |
|---|---:|---:|
| build | 0.076 / 0.086 / 0.118 / 0.153 | 0.075 / 0.083 / 0.119 / 0.170 |
| copy_transform | 0.360 / 0.510 / 0.585 / 0.746 | 0.339 / 0.490 / 0.554 / 0.691 |
| serialize_stringify | 0.944 / 1.037 / 1.357 / 1.640 | 0.923 / 1.020 / 1.454 / 1.804 |
| encode | 0.026 / 0.030 / 0.043 / 0.077 | 0.025 / 0.030 / 0.044 / 0.112 |
| open | 0.288 / 0.198 / 0.260 / 39.926 | 0.544 / 0.170 / 0.263 / 477.251 |
| write | 0.068 / 0.081 / 0.105 / 0.608 | 0.085 / 0.148 / 0.187 / 0.531 |
| flush_close | 0.066 / 0.079 / 0.095 / 0.367 | 0.073 / 0.122 / 0.162 / 1.127 |
| verify_read | — | 0.015 / 0.019 / 0.033 / 0.079 |
| verify_compare | — | 0.007 / 0.008 / 0.012 / 0.093 |
| replace | 0.410 / 0.467 / 0.527 / 38.414 | 1.016 / 0.908 / 1.005 / 422.008 |
| other | 0.002 / 0.003 / 0.003 / 0.008 | 0.011 / 0.013 / 0.023 / 0.102 |
| total | 2.246 / 2.320 / 3.307 / 41.874 | 3.110 / 2.734 / 3.555 / 479.511 |

基线 CPU 阶段合计 avg/P95/P99/max：1.405 / 1.571 / 2.032 / 2.402；文件阶段（含 replace）：0.831 / 0.784 / 0.996 / 40.421。最终候选分别为 1.368 / 1.544 / 2.158 / 2.534 和 1.732 / 1.267 / 1.477 / 478.182。`total` 为前端构建/序列化加文件工作时间；候选的主线程阻塞另算，普通保存不包含后台文件等待，即时保存包含等待旧线程的时间。请求到提交包含排队，不能作为 CPU 时间。

基线原因分组（15min + 六页正式/预热采样，各列为组内均值）：

| reason | count | bytes 均值（范围） | build | copy/transform | serialize | encode | IO（不含 replace） | replace | total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| advance_planets | 1109 | 31439 (26094–34821) | 0.076 | 0.354 | 0.937 | 0.026 | 0.383 | 0.438 | 2.224 |
| advance_planets+begin_retreat | 1 | 31903 (31903–31903) | 0.076 | 0.332 | 0.912 | 0.024 | 0.304 | 0.391 | 2.050 |
| advance_planets+collect | 6 | 31282 (28430–32021) | 0.071 | 0.364 | 0.911 | 0.025 | 0.295 | 0.397 | 2.071 |
| advance_planets+combine_all_jewels | 2 | 30052 (29838–30267) | 0.073 | 0.359 | 0.900 | 0.023 | 0.290 | 0.360 | 2.018 |
| advance_planets+equalize_reactor_allocation | 1 | 30524 (30524–30524) | 0.073 | 0.309 | 0.881 | 0.024 | 0.277 | 0.354 | 1.928 |
| advance_planets+jewels_changed | 2 | 29002 (27032–30973) | 0.067 | 0.331 | 0.863 | 0.022 | 0.305 | 0.364 | 1.962 |
| advance_planets+upgrade_equipment_batch | 3 | 30713 (29693–31680) | 0.078 | 0.327 | 0.958 | 0.027 | 0.312 | 0.367 | 2.080 |
| begin_retreat | 69 | 31361 (27301–34464) | 0.077 | 0.349 | 0.935 | 0.026 | 0.519 | 0.379 | 2.294 |
| collect | 321 | 31929 (27145–35007) | 0.074 | 0.369 | 0.961 | 0.026 | 0.534 | 0.378 | 2.353 |
| collect+begin_retreat | 1 | 30285 (30285–30285) | 0.071 | 0.336 | 0.858 | 0.025 | 0.282 | 0.341 | 1.922 |
| collect+jewels_changed | 15 | 31439 (30111–34274) | 0.077 | 0.352 | 0.975 | 0.027 | 0.307 | 0.375 | 2.121 |
| collect+tick | 1 | 32240 (32240–32240) | 0.090 | 0.389 | 1.027 | 0.029 | 0.322 | 0.417 | 2.284 |
| combine_all_jewels | 130 | 31248 (26874–34518) | 0.073 | 0.358 | 0.949 | 0.026 | 0.299 | 0.384 | 2.098 |
| combine_all_jewels+collect | 1 | 30577 (30577–30577) | 0.071 | 0.319 | 0.935 | 0.029 | 0.289 | 0.365 | 2.019 |
| combine_all_jewels+jewels_changed | 17 | 31207 (26798–33923) | 0.076 | 0.332 | 0.921 | 0.025 | 0.269 | 0.369 | 2.001 |
| equalize_reactor_allocation | 2 | 31112 (31110–31113) | 0.076 | 0.342 | 0.915 | 0.024 | 0.299 | 0.357 | 2.023 |
| generate_scientist+distribute_scientists | 2 | 31727 (31365–32089) | 0.073 | 0.310 | 0.922 | 0.025 | 0.277 | 0.359 | 1.975 |
| generate_scientist+distribute_scientists+upgrade_equipment_batch | 1 | 32071 (32071–32071) | 0.075 | 0.343 | 1.016 | 0.027 | 0.320 | 0.369 | 2.160 |
| jewels_changed | 182 | 31530 (26475–34900) | 0.075 | 0.359 | 0.944 | 0.026 | 0.386 | 0.381 | 2.180 |
| jewels_changed+tick | 1 | 32240 (32240–32240) | 0.085 | 0.339 | 0.946 | 0.025 | 0.298 | 0.352 | 2.055 |
| tick | 183 | 31448 (26323–34831) | 0.076 | 0.394 | 0.953 | 0.026 | 0.621 | 0.374 | 2.454 |
| tick+begin_retreat | 1 | 28284 (28284–28284) | 0.066 | 0.320 | 0.793 | 0.022 | 0.302 | 0.364 | 1.877 |
| tick+jewels_changed | 1 | 33835 (33835–33835) | 0.077 | 0.533 | 0.999 | 0.026 | 0.319 | 0.357 | 2.320 |
| upgrade_equipment_batch | 47 | 31660 (27131–34641) | 0.076 | 0.350 | 0.943 | 0.025 | 0.304 | 0.390 | 2.099 |
| upgrade_equipment_batch+combine_all_jewels | 8 | 32922 (30188–34432) | 0.075 | 0.359 | 0.994 | 0.026 | 0.288 | 0.366 | 2.117 |
| upgrade_equipment_batch+combine_all_jewels+jewels_changed | 2 | 32808 (31497–34118) | 0.074 | 0.333 | 0.977 | 0.026 | 0.253 | 0.350 | 2.022 |
| upgrade_reactor+equalize_reactor_allocation | 3 | 30825 (29807–32157) | 0.079 | 0.401 | 0.923 | 0.025 | 0.309 | 0.370 | 2.118 |

最终候选原因分组：

| reason | count | bytes 均值（范围） | build | copy/transform | serialize | encode | IO（不含 replace） | replace | total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| advance_planets | 1109 | 31439 (26096–34823) | 0.075 | 0.332 | 0.915 | 0.025 | 0.367 | 0.736 | 2.468 |
| advance_planets+begin_retreat | 1 | 31901 (31901–31901) | 0.076 | 0.320 | 0.958 | 0.024 | 0.365 | 0.629 | 2.389 |
| advance_planets+collect | 6 | 31265 (28427–32019) | 0.071 | 0.331 | 0.906 | 0.024 | 0.305 | 0.760 | 2.415 |
| advance_planets+combine_all_jewels | 2 | 30052 (29840–30264) | 0.067 | 0.315 | 0.856 | 0.022 | 0.304 | 0.639 | 2.218 |
| advance_planets+equalize_reactor_allocation | 1 | 30522 (30522–30522) | 0.074 | 0.282 | 0.856 | 0.024 | 0.283 | 0.648 | 2.182 |
| advance_planets+jewels_changed | 2 | 29004 (27032–30976) | 0.068 | 0.312 | 0.827 | 0.022 | 0.298 | 0.718 | 2.262 |
| advance_planets+upgrade_equipment_batch | 3 | 30714 (29691–31678) | 0.071 | 0.285 | 0.875 | 0.024 | 0.349 | 0.631 | 2.251 |
| begin_retreat | 69 | 31362 (27300–34464) | 0.075 | 0.322 | 0.922 | 0.025 | 0.299 | 0.681 | 2.339 |
| collect | 320 | 31928 (27145–35009) | 0.074 | 0.353 | 0.943 | 0.026 | 0.726 | 2.550 | 4.688 |
| collect+begin_retreat | 1 | 30286 (30286–30286) | 0.068 | 0.304 | 0.843 | 0.023 | 0.324 | 0.622 | 2.199 |
| collect+jewels_changed | 15 | 31454 (30115–34276) | 0.073 | 0.323 | 0.899 | 0.025 | 0.314 | 0.743 | 2.394 |
| collect+tick | 1 | 32242 (32242–32242) | 0.070 | 0.344 | 0.947 | 0.025 | 0.306 | 0.748 | 2.459 |
| combine_all_jewels | 130 | 31248 (26870–34520) | 0.072 | 0.340 | 0.929 | 0.025 | 4.074 | 0.703 | 6.159 |
| combine_all_jewels+collect | 1 | 30575 (30575–30575) | 0.068 | 0.296 | 0.869 | 0.024 | 0.288 | 0.657 | 2.218 |
| combine_all_jewels+jewels_changed | 17 | 31209 (26798–33923) | 0.074 | 0.304 | 0.915 | 0.025 | 0.273 | 0.671 | 2.278 |
| equalize_reactor_allocation | 2 | 31027 (30941–31113) | 0.072 | 0.311 | 0.895 | 0.024 | 0.312 | 0.665 | 2.295 |
| generate_scientist+distribute_scientists | 2 | 31730 (31369–32092) | 0.072 | 0.306 | 0.919 | 0.025 | 0.320 | 0.630 | 2.287 |
| generate_scientist+distribute_scientists+upgrade_equipment_batch | 1 | 32067 (32067–32067) | 0.076 | 0.326 | 0.945 | 0.026 | 0.283 | 0.770 | 2.441 |
| jewels_changed | 182 | 31533 (26475–34900) | 0.074 | 0.337 | 0.930 | 0.026 | 0.569 | 0.725 | 2.678 |
| jewels_changed+tick | 1 | 32239 (32239–32239) | 0.074 | 0.320 | 0.933 | 0.025 | 0.285 | 0.635 | 2.285 |
| tick | 183 | 31447 (26323–34833) | 0.075 | 0.369 | 0.923 | 0.025 | 0.505 | 0.867 | 2.782 |
| tick+begin_retreat | 1 | 28281 (28281–28281) | 0.064 | 0.292 | 0.786 | 0.022 | 0.337 | 0.763 | 2.280 |
| tick+jewels_changed | 1 | 33837 (33837–33837) | 0.077 | 0.522 | 1.067 | 0.027 | 0.335 | 0.623 | 2.668 |
| upgrade_equipment_batch | 47 | 31660 (27131–34643) | 0.074 | 0.329 | 0.935 | 0.026 | 2.264 | 0.715 | 4.359 |
| upgrade_equipment_batch+combine_all_jewels | 8 | 32924 (30190–34433) | 0.074 | 0.362 | 0.983 | 0.026 | 0.296 | 0.657 | 2.413 |
| upgrade_equipment_batch+combine_all_jewels+jewels_changed | 2 | 32808 (31496–34119) | 0.077 | 0.327 | 0.966 | 0.025 | 0.257 | 0.615 | 2.282 |
| upgrade_reactor+equalize_reactor_allocation | 3 | 30824 (29805–32156) | 0.072 | 0.348 | 0.916 | 0.024 | 0.286 | 0.624 | 2.285 |

基线长跑 2112 次写盘，最终候选 2111 次写盘、2112 次保存请求；成功数分别为 2112 / 2111。候选少一次写盘是旧 pending 被新快照合并，`written=false`，不是保存失败。大小均值 31511→31511 bytes，最大 35007→35009。计数在测量结束后单独遍历，不增加每次保存成本：基线实际最终文件 261 dict / 101 array / 0 object；候选 261 dict / 101 array / 0 object。旧基线原始 JSON 的 `container_counts` 是内存 profile 的计数，应以补充 [磁盘 census](../test/work/saved-diagnosis-tail-baseline/baseline-disk-census.json) 对照最终保存投影。不同长跑的墙钟时间和少量历史记录差异不用于等价性证明。

## Slow-save traces

基线 >10 / >20 / >30ms 保存为 16 / 7 / 3；最终候选为 18 / 9 / 5。所有 >10ms 完整 trace（因此也覆盖 >20ms）保存在 [baseline-long-detail-summary.json](../test/work/saved-diagnosis-tail-baseline/baseline-long-detail-summary.json)、[stream-long-detail-summary.json](../test/work/saved-diagnosis-tail-candidate/stream-long-detail-summary.json) 的 `slow_saves` 中。每条含原因、bytes、全部阶段、保存编号、同帧 wall/CPU、关卡/状态、实体数量，以及 battle/state/UI/planet/crew 函数事件计数和累计/最大耗时；完整请求列表和帧证据见对应无 `-summary` 的原始 JSON。旧基线长跑 index 曾固定为 300，因此以唯一 `save_id` 标识保存，不能把这个 index 当作真实长跑帧号；最终候选已修正串行帧编号。

事件包装为包含子调用的墙钟计时，例如 `crew_system.advance` 可包含宝石同步保存；不能把嵌套事件和 save 时间再相加为总 CPU。三条基线 30ms+ 保存的完整阶段（build / copy / stringify / encode / open / write / flush_close / replace / other）：

| save_id / 原因 | bytes | 完整阶段 ms | total | 同帧事件与帧耗时 |
|---|---:|---|---:|---|
| 758 / advance_planets+end_frame_save_batch | 30814 | 0.070 / 0.418 / 0.928 / 0.024 / 39.926 / 0.062 / 0.061 / 0.372 / 0.002 | 41.874 | crew_panel.refresh, crew_system.advance, crew_system.gain_exp, game.add_crew_exp, game.advance_planets, game.tick, main.on_event；wall 50.797 / CPU 48.167 |
| 598 / advance_planets+end_frame_save_batch | 31869 | 0.078 / 0.335 / 0.927 / 0.026 / 0.173 / 0.064 / 0.064 / 38.414 / 0.003 | 40.094 | crew_panel.refresh, crew_system.advance, crew_system.gain_exp, game.add_crew_exp, game.advance_planets, game.tick, main.on_event；wall 56.593 / CPU 48.977 |
| 1777 / collect+end_frame_save_batch | 33736 | 0.076 / 0.423 / 1.020 / 0.026 / 28.848 / 0.064 / 0.066 / 0.390 / 0.002 | 30.928 | crew_system.advance, game.advance_planets, game.tick, main.on_event；wall 35.763 / CPU 32.283 |

直接分离阻塞的例子：最终 2x 保存 #50（`advance_planets+collect`，28459 bytes）完整工作 59.179ms，其中 replace 57.664ms；主线程保存阻塞 1.314ms，对应请求帧 wall 16.664ms、CPU 5.965ms，请求到提交 59.369ms。文件尖峰依然存在，但这次普通保存没有将其带入请求帧。该条完整 trace 见 [stream-short-detail-summary.json](../test/work/saved-diagnosis-tail-candidate/stream-short-detail-summary.json)。

最终长跑的两个 >33ms 帧均为必须同步的保存：`combine_all_jewels`（帧 42179）保存 total 479.511ms、open 477.251ms、主线程阻塞 479.592ms，wall 487.015ms；`upgrade_equipment_batch`（帧 42959）total 93.960ms、open 91.841ms、主线程阻塞 94.041ms，wall 101.889ms。这两次尖峰直接位于本次同步 open，完整保存与主线程阻塞仅差 0.081ms，不能把它们归因于等待旧 worker。另一次 ordinary `collect` 的后台 replace 422.008ms、请求帧 16.705ms、主线程保存阻塞 1.430ms。最终原始 JSON 的 `long_run_traces` 保留两条完整长帧。

## Confirmed root cause

基线最慢保存 41.874ms 中 open 为 39.926ms（95.35%）；另一次 40.094ms 中 replace 为 38.414ms（95.81%）。长跑 `serialize_stringify` 最大 1.640ms，UTF-8 编码最大 0.077ms。没有证据支持本轮增加状态缓存、减少深拷贝或调整 battle tick；未进行这些改动，也未延后 hit/state/UI 逻辑。

[Godot FileAccess 实现](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/core/io/file_access.cpp) 支持 `store_string` 的 UTF-8/缓冲写入等价性；[Windows 文件实现](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/drivers/windows/file_access_windows.cpp) 的 flush/close 分别调用标准文件刷新/关闭；[Windows rename 实现](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/drivers/windows/dir_access_windows.cpp) 会先删除已存在的目标，再移动源文件。因此候选用不存在的目标执行 rename：旧主档→备份，已验证临时档→主档，安装失败恢复备份；恢复自身失败时仍保留可读备份。没有将 API 时间进一步归因于杀毒、驱动或物理磁盘，没有 ETW 证据。

## Changes attempted

| 独立尝试 | before / after / delta | 结果及行为验证 |
|---|---|---|
| 普通保存队列 + 旧档备份保护，初版边界过宽 | 2x 普通保存主线程 avg 1.384ms，事务 avg 8.332ms；完整保存 avg 8.245ms，读回验证 avg 5.719ms | reverted 初版边界；ordinary 队列仅 kept 在最终隔离候选：范围缩至明确调用点；关卡完成、死亡、跃迁、重铸、购买、派遣及未知调用都保持同步。帧内出现任何关键请求即强制同步。 |
| 收窄范围并在主线程解析绝对路径 | 2x 完整保存 avg 8.374ms，读回 avg 5.816ms；帧 P99 26.546ms、max 33.637ms | 绝对路径没有测得性能收益；仅作为 worker 不访问项目状态的实现边界。收窄范围和版本/dirty 代数保护保留在最终候选。 |
| 刚关闭文件再重开验证→同一 WRITE_READ 句柄 flush/seek/read/close | 100 次独立写入验证 probe 均值 7.004→1.665ms（-5.339ms）；最终 2x verify_read avg 0.015ms，完整保存 avg 8.374→2.752ms，事务 avg 8.238→2.362ms | 同句柄验证 kept 在候选；关闭后重开方案 reverted。bytes、length 和 error 全部核对，截断写入被拒绝，旧档不动。探针证据见隔离测试目录的 `test_tail_verify_probe.log` 和 `.runtime/verify-probe-results.json`。 |
| 事件拆峰 / CPU 微观优化 | 无独立已证明安全收益 | 未实施；不修改状态、奖励、RNG、死亡、固定步或 UI 刷新时机。 |

最终普通范围为五秒进度检查点、普通资源/宝石领取、没有建筑状态变化的行星探索结算；仅当这些调用发生在主循环批次中才使用异步。批次外调用仍即时同步。主线程立即将完整现状态序列化为 immutable bytes；只有一个 worker 和一份最新 pending 快照，旧 pending 可合并。同步事务先等待正在写的旧快照，然后丢弃被最新状态覆盖的 pending 并提交自身。revision 加 dirty generation 防止旧成功清除后续脏标记。线程只写文件，错误在主线程发事件，失败保留 dirty 并重试。

窗口关闭先同步保存，失败拒绝退出；场景退出等待 pending 完成。清档先取消 pending 并等待 worker，再删恢复文件与主档。读档在主档不存在/无效时可读有效备份。这些是保证异步边界安全的配套行为，并非把全部保存放入线程。

行为验证（全部在隔离工程与用户目录）：`test_tail_save` 26/26，覆盖 80ms 人工文件等待、最新快照合并、旧写入顺序、真实宝石同步成功及 profile/RNG/serial/磁盘回滚、部分写入、open/安装/恢复失败、错误重试、dirty 代数、混合关键帧、真实关卡完成、场景退出、close 成败和清档无复活；已有 `test_frame_save_batch` 5/5、`test_jewel_combine_all` 55/55、`test_journey_resume` 28/28、`test_restart_save_failure` 13/13、`test_delete_save` 7/7。删除夹具在隔离 headless 运行中只跳过无纹理的截图写出，保留行为断言。

等价性 1817/1817：旧逻辑和最终候选固定重放 1800 帧、每帧两次固定 tick，对照 profile、战斗、掉落、RNG；15 个保存检查点逐字段、逐字节及 SHA-256 相同，reload/resume 相同。仅等价性隔离夹具固定墙钟与初始化 RNG；正式源码未冻结时间。哈希清单见 [tail-equivalence.json](../test/work/saved-diagnosis-tail-candidate-tests/space-battleship/.runtime/tail-equivalence.json)，各测试日志见同级隔离证据目录。

## Tail-frame before / after

以下为相同事件/阶段探针的基线→最终候选，不与上一轮无包装帧数混比。整体帧分位数仍有运行噪声，单次长跑不能证明所有帧变化均来自保存。

| 测量 | 帧数 | P99 ms | max ms | >20ms | >33ms |
|---|---:|---:|---:|---:|---:|
| 60 FPS / 1x 基线六页 | 1800 | 18.835 | 26.707 | 9 | 0 |
| 60 FPS / 1x 最终候选六页 | 1800 | 18.285 | 29.648 | 11 | 0 |
| 60 FPS / 2x 基线六页 | 1800 | 25.501 | 40.732 | 91 | 2 |
| 60 FPS / 2x 最终候选六页 | 1800 | 22.492 | 28.067 | 58 | 0 |
| 15min / 1x 基线 | 53978 | 见 0/5/15min 窗口 | 56.593 | 207 | 7 |
| 15min / 1x 最终候选 | 53951 | 见 0/5/15min 窗口 | 487.015 | 151 | 2 |

| 15min 采样窗口 | 基线 P99 / max ms | 最终候选 P99 / max ms |
|---|---:|---:|
| 0min | 16.903 / 17.406 | 17.183 / 17.305 |
| 5min | 20.522 / 21.547 | 17.306 / 19.488 |
| 15min | 16.801 / 16.958 | 16.853 / 16.988 |

最终候选主线程保存阻塞 avg / P95 / P99 / max：

| 模式 | 次数 | 阻塞 ms |
|---|---:|---:|
| immediate | 296 | 4.406 / 2.782 / 15.197 / 479.592 |
| ordinary | 1816 | 1.464 / 1.644 / 2.290 / 2.672 |

请求到提交 avg / P95 / P99 / max 为 3.352 / 2.962 / 3.823 / 479.562ms；完整保存执行为 3.110 / 2.734 / 3.555 / 479.511ms。普通保存阻塞不等于提交延迟，即时事务还可能等待尚未完成的旧 IO。

另做 A1→B1→A2→B2 两组成对 2x 复测，页面、帧位置、关卡/状态及敌舰/弹体数量逐条配对（每组 149 次保存）。整体帧数据：

| 测量 | 帧数 | P99 ms | max ms | >20ms | >33ms |
|---|---:|---:|---:|---:|---:|
| paired-a1 | 1800 | 24.879 | 30.500 | 79 | 0 |
| paired-b1 | 1800 | 24.564 | 34.858 | 74 | 1 |
| paired-a2 | 1800 | 23.192 | 28.865 | 65 | 0 |
| paired-b2 | 1800 | 22.696 | 29.034 | 61 | 0 |

普通保存的主线程阻塞稳定下降，但关键保存的常态耗时因验证和备份保护增加约 0.35–0.44ms；总体 max 没有稳定收益。按候选 ordinary/immediate 分类对照基线同位置保存，avg / P95 / P99 / max：

| 组 / 模式 | 次数 | 基线阻塞 ms | 候选阻塞 ms |
|---|---:|---:|---:|
| 1 / ordinary | 124 | 2.079 / 2.460 / 3.652 / 12.800 | 1.364 / 1.578 / 1.790 / 2.072 |
| 1 / immediate | 25 | 2.020 / 2.623 / 2.802 / 2.802 | 2.371 / 2.549 / 2.557 / 2.557 |
| 2 / ordinary | 124 | 2.053 / 2.224 / 2.747 / 14.912 | 1.364 / 1.531 / 1.710 / 2.247 |
| 2 / immediate | 25 | 1.959 / 2.139 / 2.326 / 2.326 | 2.399 / 2.591 / 2.599 / 2.599 |

配对阻塞证据见 [paired-blocking.json](../test/work/saved-diagnosis-tail-promotion/paired-blocking.json)，每次完整管线分位数与 trace 见基线/候选目录的 `paired-a1/a2/b1/b2-summary.json`。复测基线还记录了被 save_enabled 抑制的 `crew_system.changed` 请求标签，未把它们计为实际写盘；配对使用保存序列及上述帧状态，不据原因字符串是否包含这个额外标签判定行为差异。

## Remaining bottlenecks

第二轮接入当时被自动审批拒绝，随后用户明确选择定时/手动保存方案并暂不接入异步候选；当前不再等待该候选接入审批。报告里的改善只属于隔离候选。

候选没有消除底层文件等待。同步宝石事务、关键节点和退出为保证返回值/回滚仍可能遇到 30ms+，本轮已经实测到 479ms 的同步 open；也可能等待旧 ordinary writer。最坏帧从 56.593 增至 487.015ms，因此不宣称总体尾延迟已有稳定收益，不将这组结果自动推广到正式游戏。普通保存主线程不等待文件的收益有直接慢 trace 和 80ms 人工阻塞验证；它不能保证所有保存或所有帧低于 33ms。允许的普通进度在提交前有一个短暂未落盘窗口，退出会同步提交；强制终止进程无法执行退出逻辑。旧已提交档和备份仍可恢复。

battle tick、hit/state、结构重建及船员整页刷新仍会叠加。本轮没有测得新的安全拆峰依据，也没有改 GPU、画质、实体数量或战斗逻辑。整体 P99 的跨次波动需与直接的阻塞 trace 分开判断；保留候选的主要证据是有真实文件尖峰时 ordinary 主线程不等待，以及同步/失败边界验证，而非平均 FPS。
