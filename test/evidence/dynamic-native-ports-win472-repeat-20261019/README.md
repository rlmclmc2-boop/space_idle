# 脉冲 / 导弹：交错复测与最小归因

**原 +5.72% / +3.76% 未稳定复现，不能当作稳定回归结论。** 预先固定各4对、AB/BA各半，仅脉冲和导弹。16次正式重复中15次通过；第一对脉冲候选丢焦点，该整对保留但不用于趋势。有效脉冲3对、导弹4对，差异方向均有反转。另4次定点诊断均完成并通过采样/事件检查。

可明确定位的新增工作是：`prepare_geometry`在几何早退判断之前，每逻辑步重建动态炮口阵列。480步重算480次，实际原生输入仅8次。测得炮口块预算约0.021/0.028ms/上轮候选帧，只是旧单次差值的约7%/11%；它解释了局部prepare增加，解释不了全部旧差值。图形提交和render-wait未呈现稳定正增量。

**前后都已使用新弹体。** 本轮没有做新旧弹体替换，也没有关闭炮口计算或改渲染内容。仅在隔离工程计时，正式功能/美术/数值/扩展配置不变，不合main。

- [ATTRIBUTION.md](ATTRIBUTION.md)：配对结果、分段差异、炮口/原生输入/反馈预算、结论边界。
- [analysis.json](analysis.json)：逐次门槛、完整原始状态差异、有效配对统计和独立QA计时。
- [repeats-agenda.json](repeats-agenda.json)：执行前固定的平衡日程与实际顺序；[profile-agenda.json](profile-agenda.json)：后续独立诊断。
- `repeats/`：16次原样JSON.gz、完整窗口PNG、日志、外部CPU/GPU时间线与输入回执，含丢焦点失败样本。
- `profile/`：4次独立QA结果和逐次`qa.patch`。计时只在采样期RAM累计，驱动只增加冷导出，不作为正式帧率样本。
- [input-manifest.json](input-manifest.json)、[source-scope.diff](source-scope.diff)：复用DLL哈希、共同弹体/资产证据和精确差异范围。
- [profile_ports.py](profile_ports.py)：完整定点插桩生成器；[run_interleaved.py](run_interleaved.py)、[run_repeat.py](run_repeat.py)、[analyze_repeats.py](analyze_repeats.py)：重放与分析。

复现时将run_repeat.py、run_interleaved.py、profile_ports.py、analyze_repeats.py复制到同级全新的空证据目录，不复制agenda或原始结果。用新的test/work子目录，先用run_repeat.py的--prepare-only导入，再按run_interleaved.py --phase repeats执行，分析后才--phase profile。保留同级上一份证据目录，分析器会读取其输入哈希与审计函数。所有命令路径和参数保存在agenda/receipt。沿用上一份正式Windows4.7.2引擎和DLL。

剩余限制：少量配对无法证明零开销或统计等价；个别跨运行波动究竟来自调度、频率还是驱动未被唯一锁定。render-wait不是硬件GPU timestamp。原始完整状态hash仍只有RNG seed及衍生hash不同，实际state及其他导出状态一致，未重写原始hash。无待执行采样。
