# BATTLE: weapon/buff/gem integration
SRC: authorized tables/user-approved exceptions. Stable battle behavior: PROJECT.
- New/changed attack -> trace public fire/damage path; reuse attack trigger -> shared modifiers -> damage -> hit/kill triggers. NO per-weapon effect copies or bypass for timing/target/visual differences.
- Check double/additional shot, crit, damage bonus, CD, gem, buff, affix, hit/kill effects. For beam/charge/AOE define attack vs hit boundary, modifier timing, count, source. Cover charge, periodic hit, interruption, retarget, kill; no missed/duplicate/recursive triggers.
- VERIFY affected attack-type × common-effect combinations, including old weapons; record applies/excluded + evidence. Single-weapon pass != compatibility.
- Unsupported effect requires table/user approval; record scope/behavior in PROJECT, add validation/player notice if needed. Missing impl != unsupported rule; unresolved -> STATUS.

## 体验改动的性能边界
- 新增机制不得为方便实现而大幅调整战斗计算框架；接入既有唯一权威、编译/更新和事件路径，保留已验收优化，禁止双算、另造展示计算或旧热路径外再套转换重建。
- 父审新增热路径的触发频率与复杂度：重复求值、每步全量扫描、逐事件对象/字典分配、跨层复制、过量上传与同步等待。能在配置变化时编译或在真实事件上更新的，不搬到每帧重算。必要新成本须解释用途与上界。
- 沿用冻结且等价工作量、真实1倍、60Hz逻辑、完整画面、关闭FPS上限/VSync并确认焦点的口径，仅测受影响场景；比较完整整帧、逻辑忙帧与尾部波动，计入新增维护/提交成本。不得删负载或画质伪造无回退。
- 新功能本身不要求节省0.5ms；旧优化候选保留门槛仍是完整帧净省至少0.5ms且区别于漂移。任何可分辨的性能恶化须定位并解决或交父明确权衡，不能把0.5ms当允许功能回退的预算。未达到的忙帧<10ms目标不得宣称达成。
- 本轮性能探索已暂停；必要回退核查不扩展成新的优化项目或完整宽测。
