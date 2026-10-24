# 第一阶段：从清空基线重新建设

基线为 `f1e2358b981743da4452e30e052568c6eee8b858`。方案唯一入口是 [a815d2a 的 README](https://github.com/rlmclmc2-boop/space_idle/blob/a815d2a843976e22cb3fb24e7683d4a54c65fd3f/space-battleship/docs/game-design/README.md)，本次只实现 07 第一步。这里的实现和测试均重新编写，没有恢复已删除的旧业务或上一轮实现。

## 组件与边界

- `compile_config.py`：固定 schema、显式生产/fixture 清单、Excel 字节快照、诊断、稳定 ID 索引、语义及来源 hash、版本文件和原子 active 指针。运行时不读取工作簿或旧 JSON 投影。
- `addons/native_battle/src/amount_value.hpp`：单一非负 Amount 值类型；普通和巨大数使用同一算术。`amount_api.hpp` 通过 `FoundationAmount.apply(operation, operands)` 公开同一实现。
- `host/config_bundle.gd`：核对编译指针和 checksum，查询返回分离副本。
- `host/save_files.gd`：单 writer、请求快照、串行/合并待写请求、generation/changeNumber、A/B 数据文件及主/备指针。`FoundationDisk` 只提供新文件替换原语，未恢复旧存档锁。
- `host/check_foundation.gd`：独立 Excel 经同一编译器进入同一 DLL；加载实际 `SpaceCombatKernel`，不启动旧主场景，也不建立另一套战斗。

本阶段没有可玩的 GameSession，也没有把原 native 核的 double 战斗金额迁入 Amount。静态装备、历史动态、四武器完整规则、波次、航行和掉落属于第二阶段，审核通过前不实施。保存目前验证 envelope 和 opaque Dictionary，不承担完整跨域 ID/占用/奖励/Amount 校验或加载战场恢复；那些仍属于后续保存阶段。完整布局包络、超空间奖励来源语义及其他领域运行规则也不因本次基础编译而宣称完成。

## 配置来源

`config/production.json` 完整列出 30 个输入文件：27 个根工作簿和 3 个发布副本。正式/停用内容进入 45 张表、14,563 行。`battle_design.xlsx` 为候选，`level_monGroup_generated.xlsx` 为生成副本，`published/` 为发布副本；它们仅记录来源，不覆盖正式表。仓库根旧总表不在运行清单中。旧 hightech 与已无消费者字段仅保留内容，不启用功能。

schema 是提交的静态声明，编译不依据当前值推断类型、填默认业务值或导入旧工具。它包含列、类型、可空性、主键、引用、已登记规则、排序作用域及零预算标记语义。生产清单必须完整匹配声明；fixture 可显式提供自己所需的最小定义，不会从正式表补行。

校验覆盖：字面量/缓存公式、非有限值、必填/主键/范围、外键、主线战点顺序、敌舰装备与掉落引用、科研前置和环、解锁目标、typed literal、作用域 order、显式槽位重复/边界、区间顺序。42 条零预算成员标记保持原样。编译器负例与全量逐字段内容比较见 `tests/test_compiler.py`。

本次按已定目标改动的配置：

- `enhance_config.xlsx`：第二代连发为 0；主效果 25% 与保底原率爆伤的说明明确化。
- `hyperspace_config.xlsx`：最低层 5→1、门票 108000→0；10 秒下限原本已满足，未再改值。
- `galaxy_config.xlsx`：新增 `income_basis=native_average_per_second`；将声明为 bool 的旧数值 1 显式写为 Excel bool true。编译器不做这种隐式转换。
- 新 `equipment_evolution.xlsx`：完整迁移获准保留的现存进化字段，含材料与十色外观内容；列表作为明确 JSON 文本单元格保存。原 JSON 仅保留为迁移来源，编译和运行不读取它。

未修改正式关卡、敌人、编队和资产。已删除的冻结来源 JSON/旧校验器没有恢复；不能声称缺失的逐波 source_group 历史来源或旧模板元数据已完整重建。

## 数值与保存合同

Amount 的范围是指数 ±9×10^15、15 位有效数字，指数对齐差大于 16 时忽略小项。零为 `(0,0)`，非零尾数在 `[1,10)`；保存编码为 `{m:string,e:string}`。禁止负数/NaN/INF/除零，输入或计算上溢返回明确错误，下溢规范为零。接近相等的减法先在规范尾数的 15 位表示内解决抵消，不另存精确账本。`floor/ceil` 在个位不可表示时保持近似原值。缩放比例只由明确的 `to_ratio` 返回有界 float，不将大数转普通伤害上限。

保存目录由调用方显式指定，没有个人存档默认路径。请求在主线程复制和序列化，后台不遍历运行中数据。新槽写入、flush/回读、校验 envelope 后才切指针；失败时保留已验证的旧指针，损坏主指针可回退备份。不同 configHash 的已有存储拒绝覆盖。一个存储由一个 SaveFiles 实例拥有；尚不支持多个进程/实例同时写同一目录。`close()` 为非阻塞状态查询，由未来宿主在有限关闭预算内 poll，不能把 busy 当作已保存。

Windows 原语使用 FlushFileBuffers 和 MoveFileEx 的替换/写穿标志；POSIX 分支 fsync 文件后 rename。此次运行验证仅在 Windows，未验证 POSIX 及断电持久性保证。

## 复现验证

在 `space-battleship/` 下运行，Python 需要 openpyxl。构建使用已安装的 Godot 4.7.2、Clang 和 godot-cpp，工具目录不由测试修改。

```powershell
python foundation/compile_config.py --manifest foundation/config/production.json --output .stage1-work/production
python foundation/tests/test_compiler.py
& 'D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64/bin/clang++.exe' -std=c++17 -O1 -static foundation/tests/amount_value_tests.cpp -o .stage1-work/amount.exe
& .stage1-work/amount.exe
python foundation/run_checks.py --bindings D:/CodexBuild/space_idle/godot-cpp --compiler D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64/bin/clang++.exe --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe --work .stage1-work/final
```

绑定源码固定为 `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`，构建器核对 revision。隔离构建直接编译当前 shipping C++ 源码并链接该绑定库，不依赖任何旧游戏宿主。portable engine、用户目录、日志、临时 fixture 包和测试存档全部在 `.stage1-work/`。未运行 shipping SCons/发布打包流程；测试验证的是同源隔离 DLL。

最终验证数据和源文件指纹见 `verification.json`。交付后暂停，等待 dot 与指定 Astra 双审，不进入第二阶段、不合 main。


## 首阶段审核返工

修复普通整数取整再次还原 double 后跨边界的问题：floor/ceil 直接对规范尾数的 15 位十进制表示取商/余数，避免 113 被 floor 成 112、109 被 ceil 成 110；不添加 epsilon，也不改变真实可表示的小数边界。十进制输入先按同一精度舍入再构造尾数，范围校验包含归一化指数及尾数进位；下溢仍按既定合同规范为零。

编译器对 amount_text 及紧凑掉落金额执行相同的字面量范围检查，越界返回带 Excel 坐标的 AmountRangeExceeded；主键为空或全空白返回 Required，42 条明确的零预算 null-order 标记继续保留。新增回归覆盖普通整数与邻接小数、指数上界及进位、下溢、Unicode 空白主键。返工后为 24 个编译器测试、119 项同源 DLL 断言（16 数值/1 同核/7 保存），另有原生普通整数 0–10000 与接近普通范围边界的取整检查。
