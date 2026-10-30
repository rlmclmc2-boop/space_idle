# 装备当前入口：武器／防御统一与防御精简候选

用户后续明确防御内容过多需统一／精简，并已取消Figma依赖，授权直接在原Godot组件继续。当前固定运行源码 `3916ffbc9e246f07693a633a772536faad982258`；最新[共用字段精简候选](shared-field-reduction/README.md)含同版完整武器/防御同物、替换、可用/不可用、真实装甲安装及原冷却/Batch共8整屏＋4原像素局部，全部实际看过。当前交根/原唯一Astra重新整体审，不自判用户接受，不等待用户重给品质或Figma节点，不pushmain。

最小呈现修正：防御比较只“现装／替换后”及必要容量，撤重复装甲/护盾名称；武器同结构附原Owner周期。两类候选都撤“待安装”复述，保候选名称、选中/已装备及明确安装目标；冷却只顶部秒数与原Native禁用，去重复冷却tooltip但其它Owner拒绝原因保留。费用统一标“升级费用”，65铁仍是当前护盾槽购级报价而非安装费，当前→升级后/真实费用/购买对象不变。未增加恢复率等字段、叠节点或新状态皮肤；舰体、工作台范围、原画材质及左右几何保持。

main功能认可范围、两键×1→×10→MAX只报价且购买独立、Owner价格/准入/精准局部刷新、无记录/最近结果、未锁纯空位无交互、资源icon_modulate原色、标题沿壳切角保持。卸下入口是用户已取消设计，非遗漏，不恢复；[信息组织提案](header-inner-chamfer/information-layout-proposal.md)与[高度分析](header-inner-chamfer/height-feasibility.md)仅历史存档，不复活大压缩/详情重排。公共宿主及共用状态由整体组协调。

原[9e右侧比例/装甲展示/亮态](candidate-balance-and-armour/README.md)源码 `9e420e1c184d355133737a72f716358203ffa51a`／证据 `ca6914ed3f64eef510c9ca421360a97359ed33f0`，以及[fc共同受光](lighting-coherence/README.md)源码 `fc361675131aa59ce21ec270a5aaa7e9715f9746`／证据 `784d8de3536afaae0bb430506ab1dfc697bcd8d5`和旧f72共享接入记录均保各自时点；不外推本3916已组合或已审。已取消的[Figma尝试/字段准备](candidate-balance-and-armour/figma-field-mapping.md)仅历史，0节点/0上传；停止一切Figma调用/额度探测，不作为本轮实施门槛。

本版解析与原8阶段必要视觉过程通过，含一次实际装甲安装；没有购买/独立交易全链/36、冷却到期、自然成长、全舰全槽、极端MAX、focus/hover/pressed矩阵、Windows-DPI或共享宿主组合新测。保留全部旧证据边界，0失败/字段减少不代替完整整体品质判断。
