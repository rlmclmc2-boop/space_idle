# Windows 4.7.2：既有五套高负载前后对照

两版正式 DLL 与十次图形运行已完成。原始运行门槛 10/10 通过，采样/事件配对 5/5 通过；严格原始全状态哈希配对 0/5 通过，唯一字段差异为 RNG `seed` 和派生哈希。不能将本报告表述为“完整原始状态哈希完全一致”。

## 构建与环境

- 基线 `c4a5e25968e757adc3a0ceb5bc741a615600f5bd`；候选 `6e8d2ed992f4239219a1348a7929ee04c59abf6a`。
- 正式引擎 `4.7.2.stable.official.ed1daf0bf`，现场导出 API SHA256 与原正式配套值一致：`d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`。
- 原样 `addons/native_battle/build_native.ps1`；独立 D 盘 BuildRoot；固定 godot-cpp `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`；clang23.1.3 / llvm-mingw；Windows x86_64 template_release、静态 C++、lto=none、禁 fast-math 与 FMA contraction。两版使用同一份绑定静态库，构建退出码均为 0。
- DLL SHA256：before `535c33b2b1a6db6e14228267d5ddeb5067ae2d01a19d8f693cdeb2d7080a6f7a`；after `5aa87366512b36bcc1734c3827ad4607fe0ba5d7ee2ae2f402897d8d362abec6`。
- Windows10.0.19044，i7-10700K（8核16线程），RTX2060，驱动32.0.16.1088；GL Compatibility。项目窗口覆盖值沿用1373×883；十次实际窗口尺寸见原始sampling_config，十张完整根视口图均为1372×883，完整1952×1256逻辑画布缩放显示。两版静态资源一致。
- 源码白名单稀疏检出，补齐实际 load/preload 的 toon_ship 模型/VFX/着色器；全部静态 preload 与场景资源引用存在，正式引擎导入无错误。没有下载历史美术视频来充当运行资源。

## 门槛与一致性

逐字节使用 Git 中既有 `ai-tech-final-matched-five-weapon/perf_driver.gd`、mixed/单武器夹具和原 probe/counter。Windows checkout 换行不进入冻结输入：部署直接读取 Git blob。驱动、步进循环、观测回调、预热/采样门槛均未改写。原 Windows 扩展模板逐字节部署到冻结驱动要求的隔离根路径。

十次均满足：15锁血敌人、强化40、五无人机、layer2、实际1×、固定60Hz逻辑、uncapped、VSync关闭、全程前台、native admitted、生产 stat cache 与 compiled rules 开启、save关闭；预热精确240步，采样精确480步；无脚本或运行错误。四个互斥墙钟分段均非负，逐帧之和等于完整墙钟帧耗时，全部原始数组长度一致、步数之和480。每组 warm/sample fire/hit、升级、handoff、全部事件字典、累计 stress 事件和夹具配置均完全一致。

原始夹具写入8个140级普通武器槽；`game.weapon_entries()` 在当前规则实际启用5槽，另3槽保持停用，和十张原图一致。前后启用数量与普通等级一致，没有改夹具扩容或替换为低负载；原自动升级调度照常运行，因此采样末启用装备显示152级。

`validity.json` 中 `all_five_sampling_event_pairs_valid=true`，`all_five_pairs_valid=false`。后者明确保留完整原始状态比较失败，不用规范化结果覆盖它。

## 性能观察

单位ms，箭头为基线→候选；正百分比表示帧时间增加。每套只有一个既有前后样本，不据此宣称稳定回归或统一优化收益。

| Case | 墙钟均值 | 差异 | 墙钟p95 | Logic Hz | Render Hz |
|---|---:|---:|---:|---:|---:|
| mixed | 7.581 → 7.631 | +0.66% | 10.992 → 11.071 | 60.36 → 60.37 | 131.91 → 131.05 |
| laser | 5.471 → 5.784 | +5.72% | 8.529 → 9.360 | 60.63 → 60.45 | 182.78 → 172.90 |
| cannon | 7.317 → 7.317 | 约0.00% | 10.875 → 10.891 | 59.96 → 59.91 | 136.66 → 136.66 |
| missile | 6.788 → 7.043 | +3.76% | 9.398 → 9.782 | 60.23 → 60.26 | 147.32 → 141.98 |
| longLaser | 9.201 → 8.937 | -2.87% | 13.843 → 13.398 | 60.03 → 60.15 | 108.68 → 111.90 |

| Case | before_main均值 | main均值 | submit均值 | render_wait均值 |
|---|---:|---:|---:|---:|
| mixed | 0.042 → 0.042 | 2.794 → 2.859 | 2.084 → 2.110 | 2.660 → 2.619 |
| laser | 0.034 → 0.038 | 2.259 → 2.421 | 0.948 → 0.987 | 2.230 → 2.337 |
| cannon | 0.038 → 0.037 | 2.157 → 2.173 | 2.686 → 2.694 | 2.436 → 2.413 |
| missile | 0.039 → 0.043 | 2.252 → 2.380 | 2.113 → 2.169 | 2.383 → 2.451 |
| longLaser | 0.045 → 0.041 | 3.041 → 2.933 | 3.586 → 3.487 | 2.528 → 2.476 |

main/submit/render_wait 是冻结驱动的墙钟分段，不是硬件 GPU timestamp。完整定义及每帧原始时间戳保存在 `phases`。

## 原始哈希缺口

五组在预热端和采样末端的完整原始 hash 均不相等。递归比较各端整个导出状态后，差异严格限于 `canonical_kernel/rng/seed` 和派生 `kernel_hash`；`canonical_kernel/rng/state`、`kernel_rng`、`game_rng`、所有其他导出数值字段、运动/伤害/资源/队列/beam状态均相等。原始值与差异路径全部保留。

两版共同的 C++ configure 路径都是 `rng.instantiate(); rng->set_state(int64_t(d.get("rng_state", 1)));`，没有固定该对象的 seed；冻结驱动却将 state 与 seed 都纳入 hash。只去掉这一个 seed 字段及其派生 hash 的附加诊断在十个端点全部一致，但这不等于原始 hash 门槛通过。本任务未改游戏或冻结夹具来固定 seed，也未为得到匹配 hash 重跑。

## 外部CPU/GPU观察与限制

| Case | 进程CPU秒（before→after） | 整卡GPU利用率均值（before→after） |
|---|---:|---:|
| mixed | 7.901 → 7.966 | 9.51 → 9.51% |
| laser | 7.838 → 7.755 | 11.49 → 10.99% |
| cannon | 7.891 → 7.904 | 8.45 → 8.31% |
| missile | 7.892 → 7.980 | 10.62 → 10.08% |
| longLaser | 7.913 → 7.903 | 8.00 → 8.00% |

GetProcessTimes每50ms采样，使用冻结驱动的UNIX起止包络插值，最大边界括区50.898ms。该包络包含冷端点导出，比墙钟采样区间略长；不是同精度的逐帧CPU计时。one_core_percent以一个逻辑核为100%，不是全机占用。
nvidia-smi每100ms读取整张RTX2060，按本机UTC+08时间戳对齐驱动UNIX包络；包含桌面及其他进程，传感器刷新可能慢于轮询，不是游戏独占GPU时间。物理GPU帧时间/每进程GPU耗时仍未采集。
本轮没有多次交错重复、统计显著性或自动回归阈值结论。新接口的独立正确性专项不在本次授权范围，本报告只交付必要构建与既有五套负载。所有运行均完成，没有待执行的采样；剩余验收缺口是严格完整原始状态哈希以及上述计量限制。

## 原始数据与复现

本目录保留十份原样JSON.gz、十张完整画面、两版DLL包、构建/运行/导入日志、命令与输入hash回执、GetProcessTimes原始时间线及NVIDIA CSV。`state-differences.json` 和 `rng-and-render-audit.json` 可直接复核hash缺口。用本目录 runner 的全新输出目录重放；分析命令为 `python analyze_windows_perf.py <output>`。没有覆盖或挑选有效结果，也没有将Linux诊断当作Windows结果。
