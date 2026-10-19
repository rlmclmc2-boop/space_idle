# dynamic-native-ports-win472-20261019 — completed

范围：仅正式Windows4.7.2必要原生构建及既有五套完整画面高负载前后对照；不改功能、美术、数值或正式扩展参数，不合main。

基线 `c4a5e25968e757adc3a0ceb5bc741a615600f5bd`；候选 `6e8d2ed992f4239219a1348a7929ee04c59abf6a`。独立分支 `test/dynamic-native-ports-win472-20261019`。

两版原样build_native.ps1构建成功；固定正式API和godot-cpp，同一绑定库，源码Git blob已核验。独立测试工程与用户目录，原冻结驱动/夹具不变；十次串行运行均精确240/480步、actual1x/focus/native门槛通过、无脚本或运行错误。五组事件/配置一致，四段帧耗时检查通过。

完整原始状态哈希严格相等未通过：五组的预热与采样末端差异仅为导出RNG对象seed及派生kernel_hash；实际RNG state及其他导出字段一致。seed排除诊断仅作附加解释，不覆盖原始失败。未修改游戏或冻结夹具消除该差异。

墙钟均值差异：mixed +0.66%、laser +5.72%、cannon约0%、missile +3.76%、longLaser −2.87%。每套一个前后样本；不宣称统一收益或统计回归。GetProcessTimes为50ms外部包络插值；NVIDIA为100ms整卡观察，未采集物理GPU逐帧耗时。

证据：`test/evidence/dynamic-native-ports-win472-20261019/README.md`、`PERFORMANCE.md`、`validity.json`、原始JSON.gz/日志/完整画面/CPU/GPU时间线、builds/manifest.json与两版DLL包。`verify_evidence.py`核验十次输入和原始证据，SHA256SUMS.json提供文件校验。

任务已完成，无待执行采样。剩余验收限制是完整原始状态哈希与上述计量精度；父线程复核后再决定后续范围。
