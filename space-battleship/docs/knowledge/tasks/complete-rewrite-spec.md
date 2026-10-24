# complete-rewrite-spec

目标：以 b4729b9a9803458b5ac19a4945c2fe0d5f76e51f 为核对基准，交付可实施的新架构设计，唯一入口 docs/rewrite-design/README.md。

范围：设计正文、功能覆盖账、Excel 表/字段/行清单、入口与保留边界、验收与未决规则。禁止修改生产实现、生产 Excel、测试代码；不运行游戏/测试、不合 main、不用 Library、不另开线程。

分支：design/complete-rewrite-spec。停止条件：文档全部填实、未决规则显式标记、覆盖账有归属和验收、仅文档变更并通过 Git 交付。

精确扩读：config_excel/**/*.xlsx 及根目录工作簿的表/列/行；data/*.json 的结构与来源；docs/project/*.md、CREW/GALAXY/UI/LEVEL_EDITOR/UI_TEXT/BALANCE_LAB；tools/supported_entrypoints.json；按功能查 scripts 具体函数及 native 内核/表现接口。缺口是全量功能/字段尚未编目和复杂无人机、工具、成长公式尚未核实；不读其他任务记录、不执行被检查代码。

风险：旧文档复活废弃玩法；将纯表现与业务混合文件整体删除；配置/测试回退掩盖源缺失；native 支持范围不足；未决业务被默认批准。

下一动作：先创建目录和覆盖账，再逐章核实并填实；记录证据与状态。
