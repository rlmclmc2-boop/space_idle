# 当前保留的基础代码

当前保留 Excel 转 JSON、共享 C++ Amount/绑定和保存骨架，没有可运行的游戏主入口。整体架构完成后再安排整体测试；本阶段只检查编译，并运行独立 Amount 的直接 C++ 正确性测试。

## Excel 导入

在 space-battleship/ 运行：

```powershell
python foundation/import_excel.py
# 也可指定另一个 Excel 目录和输出位置：
python foundation/import_excel.py --source <Excel目录> --output <输出JSON>
```

默认读取 config_excel/ 根目录的 *.xlsx，不递归进入 published/ 等子目录。输出 generated/config.json，结构为 `{工作簿文件名: {工作表名: [数据行对象]}}`。表头来自第一行，第二、三行为说明，数据从第四行起。公式读取 Excel 已保存的缓存值，导入器不计算公式。

没有逐字段 schema、逐表输入清单、主键/引用/规则检查。它只转换数据，不决定哪些候选或旧内容在游戏里启用。运行方直接读取生成 JSON，例如：

```gdscript
var text := FileAccess.get_file_as_string("res://generated/config.json")
var config = JSON.parse_string(text)
var equipment_rows: Array = config["equipment"]["equipment"]
```

这是后续游戏入口直接读取数据的方式；当前没有 GameSession、运行工程或读取调用点，本轮不提前实现第二阶段。文件名和工作表名原样作为两层键，不生成额外索引、哈希、元数据或发布指针。

不存在 ConfigBundle 或查询包装。配置修改在对应 Excel 中进行，再重新导入；生成 JSON 只是运行产物，不作为测试或人工改值的入口。

## 原生构建

Amount 值及绑定在 addons/native_battle/src/amount_value.hpp、amount_api.hpp，平台文件替换原语在 foundation_disk.hpp；与保留的 native/GPU 源码一起构建。

```powershell
powershell -ExecutionPolicy Bypass -File addons/native_battle/build_native.ps1
```

该脚本使用其参数指定的构建及工具目录，要求固定的 godot-cpp 版本和 Godot API，输出 DLL。运行程序需要加载对应 GDExtension；当前尚未建立完整游戏入口。

## 保存骨架

foundation/host/save_files.gd 通过显式目录和配置内容 hash 创建，request() 接收本次 payload 快照，poll() 回收写入结果，dirty()/close() 提供状态。保留实际保存需要的写入失败处理、flush/回读、checksum、A/B 槽与主备指针保护；测试专用故障注入已移除。没有默认个人存档路径。


## 唯一保留的正确性测试

`foundation/tests/amount_value_tests.cpp` 直接包含 `amount_value.hpp`，不依赖 Godot、Excel、配置或保存设施。它覆盖大数四则运算、幂、等比和、取整、编码范围及非法输入边界；含 0–10000 整数的 floor/ceil 一致性回归。必须启用 assert，不使用 `-DNDEBUG`。

```powershell
& '<C++编译器>' -std=c++17 -O1 -static foundation/tests/amount_value_tests.cpp -o "$env:TEMP/space-idle-amount.exe"
if ($LASTEXITCODE -eq 0) { & "$env:TEMP/space-idle-amount.exe" }
```

不保留阶段配置/保存测试、测试 Excel、无界面工程、runner 或验证记录。整体玩法、游戏中的配置读取、Godot 绑定运行和保存恢复行为均留待架构完成后整体测试。
