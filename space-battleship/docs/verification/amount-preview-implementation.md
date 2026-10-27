# Amount安全预览与Reactor整组金额：实现候选

分支`feat/amount-safe-previews`，基底/已审设计`077cd522e514fde6a715ea6d02397e50263f2509`，范围为[14第9节](../game-design/14-ui-contracts.md#9-已审设计反应炉整组草稿与科研预算的amount安全预览)。**实现候选待双审，未合main。** 没有UI、配置、存档字段、原生源码或几何变更。

## 实现边界

- Reactor：allocation_plan_preview支持shares/amounts/equal，Amount取整、完整开放集合及总额校验；current只读已接纳缓存，未初始化时未知，不把新输入预测成实际。目标在脱离状态上沿原求值，副作用不进入_state/_prepared_state。重复同源草稿复用脱离缓存，source只有公开容量与开放ID。
- apply_allocation_plan只接收确认的完整canonical整数映射，不收比例、不重算；最新容量仍容纳时保持金额，不足/集合改变拒绝。求值后逐值复核，禁止原_evaluate的钳制改变目标。一个候选、一次既有publish/accept，普通拒绝不留部分分配；成功沿choices_changed通知。均分/单设备入口不改。
- Research：budget_preview区分当前、本次草稿、持续样本；每资源净收支用方向+非负Amount，库存时长用div且rate=0不制造无穷。speed_now按当下支付条件，completion_estimate独立以funded_speed及足额资金假设求时长/所需资金，明确余额覆盖性。没有随机现金流预测。
- 单资源setter保留；非法精确字段只给该资源错误和未知目标，合法另一资源仍有可应用标记。持续0%仍InvalidResearchRatio；关闭合法自动设置不清投入或周期相位。原速度、周期投入和ratio准入抽成同一原求值供推进/预览复用，未另写UI曲线。
- 原panel_model补research_id，过期预览请求返回ResearchSelectionChanged及当前公开ID，避免调用方偷读私有state。Session.research_preview_inputs经Economy公开收入/钱包提供脱离快照及单一聚合速度因子；不向UI返回组成作失效比较。所需工作量/完成效果只在脱离数据上计算，按等级/缓存值及已接纳peak等真实来源复用；可见时新读其余事实，无新全局revision层。

## 初始候选3264858b的定向验证

[探针](../../foundation/tests/_amount_preview_probe.gd)使用现行生产编译配置、真实模块和FoundationAmount；局部状态/钱包为显式测试装配，未复制或改平衡表。原始结果及源码/工具哈希见[清单](amount-preview-evidence/manifest.json)。

| 检查 | 结果 |
|---|---|
| C101的3333/3333/3334基点→33/33/33、余2；equal→34/34/33；0容量、大额3.7e119及大容量内小额1直接求和 | 通过 |
| ID集合/缺项/越界/超额；确认金额33.9不静默floor；容量变110保持60/35/5，变90拒绝 | 通过 |
| 普通发布拒绝不改实际/准备状态、不发成功通知；成功一次发布；distribute用提交时C102→34/34/34 | 通过 |
| 当前C102/免费0与目标C110/免费22分别读取；清零手动仍保留免费10；缓存返回可改不污染所有者 | 通过 |
| 收入10.9/3.2的37%、0%、100%；持续0拒绝、合法10bp无收入样本至少1、关闭无样本 | 通过 |
| 库存25/20游戏秒及1e115秒；净赤字以正幅4.1表达；单资源非法不伪0/回滚另一成功项 | 通过 |
| 无钱speed_now=1，持续足额funded_speed=4/估时15秒；外部因子2→2/8/7.5；明确当前资金不覆盖 | 通过 |
| 无当前研究的等级/工作/速度/估时为未知；真实成长472级估时>1e100秒；本级AI/武器效果、已接纳peak更新使缓存失效 | 通过 |
| 无岗位时已到期等待、恢复岗位due；不重置相位；研究身份/工作进度变化刷新所需比较 | 通过 |
| 真状态/保存required_work/准备候选/通知/RunState不被查询改写；静态求幂复用；停机在发布前拒绝 | 通过 |
| 公开输入拒绝保留原原因，缺输入/无效来源Amount只返回读错误，不发布/制造RunState故障 | 通过 |
| 同一DLL下对077cd522原Research源码比较耗尽片段、提前完成和周期刷新；返回与保存状态逐项相同，手算片段工作2.25 | 通过 |
| 实际Session初始化→新整组入口→既有publish_reactor/native一次发布；实际公开科研输入无保存缓存副作用 | 通过 |
| Economy actual游戏窗口600/60→10，窗口自然过期变0而钱包仍600；Session输入深改不污染钱包/速度 | 通过 |

最终[原始探针日志](amount-preview-evidence/final-probe.txt)退出0；[入口check-only](amount-preview-evidence/check-only.txt)退出0；候选diff检查通过。根证书读取提示与此前相同，离线检查完成。未运行无关全套。

## 匹配原生依赖与复现

首次使用既有`D:/CodexBuild/space_idle/native-stable`产物时，Session初始化缺weapon_aims而未完成，随后中止；[原始中间日志](amount-preview-evidence/stale-native-initialization.txt)不计通过，也不是新的运行缺陷结论。该中间探针版本未单独留存，清单不伪造其源码哈希。

按仓库既有build_native.ps1，以当前未改的原生源码在`$env:TEMP/amount-preview-native-build`构建匹配DLL。构建退出0，[末尾原始字节摘录](amount-preview-evidence/native-build-tail.txt)及完整本地构建日志SHA256随清单保留；没有复制仓库/新工作区，只有该脚本的常规临时构建产物，不提交DLL/缓存。新DLL SHA256：`A8D7FF72FABDBF4B09605E9C63015CDADD57A8BC5AD18030AAE78F83A93DA7CA`。原生src固定树：`a990ed73bdb2c63471ebed15dd9ddbe500d22ce8`，相对设计基底无修改。

在space-battleship下，用原发布入口生成隔离配置，或复用清单所列已验证同哈希输出；Godot4.7.2、Clang23.1.3/godot-cpp10.0.0/API均由原构建脚本核pin。复现关键步骤：

```powershell
New-Item -ItemType Directory -Force "$env:TEMP/galaxy-ledger-rebuild" | Out-Null
python foundation/import_excel.py --output "$env:TEMP/galaxy-ledger-rebuild/config.json"
& ./addons/native_battle/build_native.ps1 -BuildRoot "$env:TEMP/amount-preview-native-build" -GodotCpp 'D:/CodexBuild/space_idle/godot-cpp' -LlvmMingw 'D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64' -Api 'D:/CodexBuild/space_idle/api/extension_api.json' -Python 'D:/CodexTools/venv/godot-native/Scripts/python.exe' -Jobs 8
$env:SPACE_IDLE_NATIVE_EXTENSION = "$env:TEMP/amount-preview-native-build/native-stable/space_native.gdextension"
$env:SPACE_IDLE_GALAXY_PROBE_CONFIG = "$env:TEMP/galaxy-ledger-rebuild/config.json"
$env:SPACE_IDLE_RESEARCH_BASELINE = "$env:TEMP/galaxy-ledger-rebuild/research-baseline-077.gd"
python -c 'from pathlib import Path; import os,subprocess; Path(os.environ["SPACE_IDLE_RESEARCH_BASELINE"]).write_bytes(subprocess.check_output(["git","show","077cd522e514fde6a715ea6d02397e50263f2509:space-battleship/src/systems/research.gd"]))'
& 'D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --log-file "$env:TEMP/galaxy-ledger-rebuild/amount-preview-delivery.log" --script res://foundation/tests/_amount_preview_probe.gd
```

限制：本次没有完整游玩/真实UI工作点接入、完整保存/重铸、随机未来现金流、native故障注入或后续M1/G9几何验证；一次真实Session发布不是完整游戏验收。原179项生成文件修改与262项未跟踪元数据保留不提交，main审批暂停不重试。设计审查历史仍见[原核对](amount-safe-preview-contract.md)，不把本地探针冒称独立双审。


## 双审修订：候选容量缓存纯度

原候选`3264858bab136d504eefb938e7582035702ecd60`的旧prepare/refresh及单项allocate/distribute路径会让_capacity在接纳前写入真_state，新current读取因而可能把新容量与旧分配/效果组合。本修订只在_evaluate、_allocate、_distribute入口深拷贝所给状态，沿原公式/钳制/发布求值，接受时才_adopt；没有第二容量账本或签名掩盖。上方初始矩阵与原manifest保留为3264858b的历史证据，不替代本次修订验证。

[新增探针](../../foundation/tests/_reactor_candidate_purity_probe.gd)对原3264858b复现10项断言失败，保留[原始失败日志](amount-preview-evidence/purity-before.txt)，未重新制造基点结果。修复后验证prepare/discard、refresh发布拒绝、allocate/distribute发布拒绝均保持完整真状态（含缓存）及current；prepare未接纳仍旧容量，accept后容量与免费效果一起更新；成功仍各一次发布、原allocate钳制145及均分67/67/66保持。新增探针[通过日志](amount-preview-evidence/purity-after.txt)退出0。

同一配置和匹配DLL下，原Amount探针（含新整组及实际Session/native发布路径）[再次通过](amount-preview-evidence/amount-after-purity.txt)，[入口check-only](amount-preview-evidence/purity-check-only.txt)退出0；未跑无关全套。新增[固定源码/配置/原始字节清单](amount-preview-evidence/purity-manifest.json)区分原基点与修订源码。根证书提示仍存在，未阻止离线探针。仍为独立候选待双审，main继续暂停，原生成物保留。
