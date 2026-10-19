# Windows 4.7.2 原有五套高负载对照

基线 `c4a5e25968e757adc3a0ceb5bc741a615600f5bd`；候选 `6e8d2ed992f4239219a1348a7929ee04c59abf6a`。

正式 Windows 原生 DLL 两版构建成功，既有 mixed / laser / cannon / missile / longLaser 已同机串行完成。10/10 次运行通过原始门槛；5/5 组采样步数、事件和原始夹具配置一致。完整状态哈希严格相等未通过：全部差异仅为导出 RNG 对象的 `seed` 及其派生 `kernel_hash`，其实际 `state` 和其他导出字段完全一致。原始哈希未被重写，也没有把去除 seed 的诊断当作原始哈希通过。

本轮未显示统一性能收益，详见 [PERFORMANCE.md](PERFORMANCE.md)。没有功能、美术、数值或正式扩展配置改动；不合 main。

- [builds/manifest.json](builds/manifest.json)：引擎、API、绑定、源码与 DLL 哈希；正式构建参数与本地 Git 输入核验。
- [builds/windows-validation.zip](builds/windows-validation.zip)：本次 before/after Windows DLL；两份构建日志位于本目录。
- [validity.json](validity.json)：逐次门槛、四段计时检查、两层配对判定和 seed-only 诊断。
- [state-differences.json](state-differences.json)、[rng-and-render-audit.json](rng-and-render-audit.json)：原始状态差异及 RNG/画面核对。
- `*-before/after.json.gz`：未经改写的 Godot 原始 JSON；`*.png`：十张完整窗口采样末图；`*.log` / `*.engine.log`：原始日志。
- `*.process.json.gz`：外部 GetProcessTimes 时间线；`*.gpu.csv`：整卡 NVIDIA 原始采样；`*.receipt.json`：逐次命令、环境、脚本/DLL/夹具哈希。
- [run_windows_perf.py](run_windows_perf.py)：原驱动逐字节部署，串行执行并拒绝覆盖已有原始结果；[analyze_windows_perf.py](analyze_windows_perf.py)：只读原始结果，输出审计。

重放时使用全新 output 与 test/work 子目录，先解压两版 DLL，以原正式 Godot4.7.2 执行 `run_windows_perf.py --repo <repo> --project <fresh-test/work/project> --before-lib <before/space_native.dll> --after-lib <after/space_native.dll> --godot <Godot4.7.2.exe> --output <fresh-output> --prepare-only`；导入成功后用相同参数去掉 `--prepare-only`，最后执行 `analyze_windows_perf.py <fresh-output>`。运行机需要 NVIDIA 的 `C:/Windows/System32/nvidia-smi.exe`。
