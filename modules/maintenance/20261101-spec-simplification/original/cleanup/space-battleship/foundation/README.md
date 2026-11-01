# 构建、配置发布与运行命令

[设计与当前制作入口](../docs/game-design/README.md)。本页只维护命令和依赖；各分支状态、现场与证据范围从设计入口查，不将历史阶段限制当当前任务。文档整理仅检查文档差异、引用和版本，不运行游戏。其他任务的运行/验证范围由本次用户授权及分支交接确定。

## Excel configuration publication

Run `python foundation/import_excel.py` from `space-battleship/`. The entry reads the 29 root workbooks in `config_excel/` using the checked-in `config_tools/production_manifest.json`; `published/` is outside this input set. It validates workbook and sheet inventory, headers, field types, required cells, primary keys, formula caches, selected cross-table references, stage and route coverage, numeric ranges, and typed rule keys. It writes `generated/config.json` only after validation and readback succeed. Failures leave the previous runtime JSON unchanged.

The entry also writes `generated/config.validation.json` with source and output hashes on success or cell-specific errors on failure. `--source`, `--output`, `--manifest`, and `--report` override these paths; an alternate source requires a test manifest. `run_game.ps1` invokes this same entry before launching Godot. The runtime shape remains `{workbook stem: {sheet name: [row objects]}}`, including explicit null-valued fields. These generated files are local artifacts and do not belong in Git.

`python -m unittest -v test_publish.py` from `config_tools/` runs publication rejection probes on copies of the real consumer tables with an independent `kind: test` manifest. The compiler rejects a test manifest pointed at production input and a production manifest pointed at test input.
## 原生构建

Amount 值及绑定在 addons/native_battle/src/amount_value.hpp、amount_api.hpp，平台文件替换原语在 foundation_disk.hpp；与保留的 native/GPU 源码一起构建。

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
```

Windows 构建前提供 `SPACE_IDLE_GODOT_CPP`（godot-cpp checkout）、`SPACE_IDLE_LLVM_MINGW`（llvm-mingw 安装根目录）及 `SPACE_IDLE_GODOT_API`（导出的 extension_api.json），也可分别用 `-GodotCpp`、`-LlvmMingw`、`-Api` 参数指定；Python 需安装 SCons，可用 `-Python` 或 `SPACE_IDLE_PYTHON` 指定。构建目录默认在用户 LocalAppData 下，可用 `-BuildRoot` 或 `SPACE_IDLE_BUILD_ROOT` 改到任意有写权限的盘。脚本校验 godot-cpp 10.0.0-stable 固定提交、Clang 23.1.3 x86_64 工具链及 Godot 4.7.2 单精度 API 哈希，输出 DLL 与 GDExtension 清单；依赖工具不随仓库交付。现有 native retained/GPU 表现读取同一个战斗核。

## 独立 Amount 正确性检查

`foundation/tests/amount_value_tests.cpp` 直接包含 `amount_value.hpp`，不依赖 Godot、Excel、配置或保存设施。它覆盖大数四则运算、幂、等比和、取整、编码范围及非法输入边界；含 0–10000 整数的 floor/ceil 一致性回归。必须启用 assert，不使用 `-DNDEBUG`。

```powershell
& '<C++编译器>' -std=c++17 -O1 -static foundation/tests/amount_value_tests.cpp -o "$env:TEMP/space-idle-amount.exe"
if ($LASTEXITCODE -eq 0) { & "$env:TEMP/space-idle-amount.exe" }
```

## 正常游戏启动

在本目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
powershell -ExecutionPolicy Bypass -File run_game.ps1
```

启动前设置 `SPACE_IDLE_GODOT` 为 Godot 4.7.2 程序路径，或以 `-Godot` 参数传入；`run_game.ps1` 与构建脚本使用相同的 `BuildRoot` 默认值或覆盖值。启动脚本先按原路线将 Excel 导入为 JSON，再运行正常 Godot 主场景。它是游戏启动入口，不是测试 runner。编译检查不会执行该启动脚本。

## 当前职责

模块归属以 [05 现行模块交接契约](../docs/game-design/05-architecture.md#现行模块交接契约)为准；页面连接见 [14](../docs/game-design/14-ui-contracts.md)，数据/保存见 [06](../docs/game-design/06-data.md)，设计场景与证据判定见 [07](../docs/game-design/07-verification.md)。
