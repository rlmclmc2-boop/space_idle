# M9最小只读读取：实现候选

分支`feat/amount-safe-previews`，实施前基线`09af963cf6f66146e019cecd08353426ab6d6abb`。设计`cad1ee17`及分册修正已双审；本运行候选待定向双审、未合main。正式契约见[超空间分册第12节](../game-design/contracts/hyperspace.md#12-实现候选m9仓储挂设改造与确认前读取)。不代表新UI接线、完整V9或游戏验收。

## 实现与原所有权

Hyperspace补实际主仓/溢出容量、五类挂设成长/准入、所选机普通词缀/传说原始参数范围及拆解份数投影。模块经验门槛和每份效果因子最小提取纯助手；保留原float域、成长循环及贡献加法顺序，非有限展示值为null并给原因。已购槽/允许增长上限/保留槽独立，锁定/究极/封存不删除可读范围；未知对象沿原原因。

Session以真实船型、cycle_reached和已接纳普通装备来源薄包装原挂设/编队/预设准备。仅投影规范ids/逐机entries和具名准入，不暴露整本贡献；scope固定hyperspace_prepare，不承诺完整native普通炮+无人机组合许可。Equipment共享原无人机武器求值体，新读取明确用actual槽；原命令仍优先pending。

当前操作改造预览保留原forecast，最小补来源修订、规范费用、可支付性与必要配装预检。费用转换与原命令共用，原抽样、报价、执行与幂等不变；局部随机候选不是已取得结果。兑换从原命令原样提取完整准备，包含候选扣源及目标Amount.add；预览不返回钱包，命令最新重验后才接纳/通知。保存宿主摘要未混入。

## 定向验证

[探针](../../foundation/tests/_m9_readonly_probe.gd)使用同配置、同FoundationAmount/native DLL，另加载实施前Git原始Hyperspace/Equipment；基线Session只调整这两项preload路径。夹具显式设置无人机、成长、余额、保护与pending边界，不修改生产配置或个人存档。

- 实际容量随重铸变化；五类经验门槛/每份贡献与原成长/聚合结果一致，阶段不足不抹除已接纳贡献；非有限值保持未知。
- 实际槽数、溢出安装、究极/封存/重复拒绝，逐机预设挂设、单项阶段失败整组拒绝；编队原容量/未知/重复准入原因一致。
- 锁定词缀与传说参数范围、究极保护/保留槽分离；返回深改不污染所有者。
- 拆解保护来源、原材料/核心与份数一致，随机种类标待结算；局部RNG不推进真实状态。
- 改造普通/保底候选、费用/抽数与基线一致；查询前后所有者保存快照、预算、随机流/修订号及预算通知不变；实际未装备改造命令/余额和重复operation_id与基线一致。
- 真正Equipment.equip_slot发布回调内，命令读取候选最高付费级，新读取仍为actual；随后accept更新、反向pending/discard保持最新actual，不改候选。
- 兑换正整数/零/小数/同材料/未知/不足、RunState顺序与旧命令相同；Amount操作轨迹包含payment扣源和目标加款。显式让can_pay成功后分别在sub_nonnegative及add返回错误，两版本保留同顺序/原因、预算不变；旧预览后预算变化确认重验。
- 99项定向断言及main入口check-only退出0，无ERROR/WARNING。原方法/抽取块与源码/依赖/原始日志字节哈希见[证据清单](m9-readonly-evidence/manifest.json)。不把本次定向结果推广为完整游戏验收。

首轮有一条夹具把Amount文本固定为普通十进制，改为Amount域比较后通过；受限执行环境读系统证书库报错，正式证据使用正常宿主权限重跑。未为夹具改变生产行为。正式两份stdout按局部-text属性保留原始字节。

## 复现与限制

按foundation/README.md使用Godot4.7.2及清单所列同哈希配置/DLL，设置SPACE_IDLE_NATIVE_EXTENSION、SPACE_IDLE_GALAXY_PROBE_CONFIG。将基线三个脚本的Git原始字节置于临时目录，基线Session仅将Equipment/Hyperspace的preload指向该临时原版；设置SPACE_IDLE_M9_BASELINE_SESSION。执行`--headless --path . --log-file <临时日志> --script res://foundation/tests/_m9_readonly_probe.gd`及`--headless --path . --log-file <临时日志> --check-only --script res://src/main.gd`。基线临时文件、配置与DLL不提交。

pending接受/丢弃仅为真实Equipment回调装配，不是跨模块native事务或正常游玩触发证明。未覆盖完整多舰/全改造随机组合、真实native故障、UI连续操作/性能、保存宿主摘要、几何或未来收益。未变更Excel、原生源码、存档格式、规则/费用或main；原179项生成修改与262项未跟踪元数据保留。
