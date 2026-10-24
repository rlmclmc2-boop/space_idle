# 重写首阶段

唯一规则入口：[a815d2a README](https://github.com/rlmclmc2-boop/space_idle/blob/a815d2a843976e22cb3fb24e7683d4a54c65fd3f/space-battleship/docs/game-design/README.md)。基线 `b4729b9a9803458b5ac19a4945c2fe0d5f76e51f`。

在 `space-battleship` 下执行；Python 3 + `openpyxl==3.1.5`。编译器不需要 Godot。

```powershell
python config_tools/compile.py --manifest config_tools/production.json --output tests/work/production
python config_tools/compile.py --manifest tests/excel/core_rules.json --output tests/work/core
python tests/test_config_compiler.py
```

`production.json` 显式列出24本44表；候选、生成、发布副本及旧总表不进入正式输入。schema固定在版本库，运行时不从Excel值推测类型。`create_stage1_inputs.py --write`仅用于审阅后的schema/独立fixture再生成，不是编译流程；它不改正式工作簿。测试Excel的资源71、敌人9101、编组9201、关卡9301及小数值均独立编写。

编译包包含全行内容、ID索引、坐标、源字节hash及来源分类；相同行数据换物理行不改语义hash。阶段1校验类型、主键、装备资源引用、主线嵌套引用/战点顺序、敌武器引用、科技拓扑、typed literal表。后续领域接入时补相应布局、预算、词缀和规则专属校验及具名运行结构；当前生产包尚未接入游戏启动入口。`ruleParameters`预留，当前不从旧代码补默认规则，也没有把基线快照冒充09章目标配置迁移。

同一C++ Amount无Godot依赖，可直接编译 `tests/amount_native.cpp`。Godot绑定 `SpaceAmount.calculate` 返回 `{ok,value:{m:string,e:string}}` 或 `{ok:false,error}`；比较/比例/对数返回scalar。这里的N01近等相减明确使用Excel中的对数容差0.001；其他本fixture金额用1e-12，期望没有调用生产公式生成。

Windows native headless（已安装Godot 4.7.2、仓库原有官方godot-cpp pin、llvm-mingw）：

```powershell
python tests/build_headless.py --bindings D:/CodexBuild/space_idle/godot-cpp --compiler D:/CodexTools/llvm-mingw/llvm-mingw-20261006-ucrt-x86_64/bin/clang++.exe --godot D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe --work tests/work/headless
```

工具把同一`space_native.cpp`及三个新组件编成隔离DLL，复制便携引擎到work，运行最小project；不打开游戏主场景，不写正式DLL或个人存档。`run_cases.gd`先运行同一编译器，再加载同一核。缺native直接失败。入口支持`--case N01-add`；生成`result.json`及日志，脚本异常也判失败。当前核仅做配置/推进入口烟测，第二阶段才接GameSession、战斗Amount链路和四武器闭环；没有第二套战斗。

`runtime/config_bundle.gd`提供校验后只读查询。`runtime/save_files.gd`提供新格式1 envelope、只读快照、单writer、generation/dirty、不可变generation文件、checksum主/备指针和故障边界。原子写由同DLL的`SpaceSaveIO` flush/替换；`SpaceSaveLock`保护同目录writer。保存测试使用work子目录，覆盖首次写、并发排队、脏标记、四个故障保旧文件。完整领域校验、导入、离线补偿、新战场恢复、超时关闭及更细flush/rename故障矩阵留给07第6步；`close()`目前是显式阻塞收尾接口，不是最终退出UI。

首阶段到此交接，等待dot与独立审核共同通过，再进入第2步。不合main。
