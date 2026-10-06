# 第一次重铸返34/通35：转换与运行交接

原件来自父 evidence/hyperspace-parent-20261006@7657e685，原始整包 SHA256 3eedee39ebcb6c7c4a5356df2e9d427e78f10dd1ac9d81e646697ec7548e2b08，X1 124437.033325902。自建 e5283ab8 完整场景包指纹13757dc31c5b2f8796cb5407bf6def1aefd1b877cda465e8a57818bfb6b2b33d。

解压 converted.bin.gz 得完整二进制CP，SHA256 29e4b7b9b45887f53097c33000eb60bca56f47309651cb3e9a7342bba81e3e81。两次转换结果相同。converter/verify_and_convert.py 接 --project --source --output；输出必须不存在。它检查固定原件SHA、两份manifest的完整指纹、18项准确hash差异白名单、当前工程所有不可变文件。Godot导入生成的.import差异单独列审计。convert.gd保留二进制Variant，不经过JSON降级，不使用仓库通用清策略转换器。

所有旧controller/RNG/save/options/safe_farm等根字段逐字节保持；旧space_policy字段全部保持，仅新增idle_salvage_enabled=true及budget round=-1/used=0/tour_started=-1；修改版本身份，追加迁移元数据及lineage，旧历史不改。生产校验inventory与hyperspace均通过，10架全部合法。生成范围与旧存量兼容范围分开：drone_master新生成0.5–0.6，旧存量0.8–0.9；此CP保留10架没有传说。

版本实际数值变化明确：35关atkRatio/lifeRatio×3；36新增entry比例锚点；无人机大师新生成范围下调且保留旧存量兼容；现代化基础价+1。e528新增QA每300秒巡视最多3次闲时挂设行动，不改生产规则。

运行用start-native.sh，设PROJECT/CHECKPOINT/RESULT隔离路径；读取runtime-options.json。相对源options仅覆盖allow_reforge=false（只测第一次重铸）与wall_limit_seconds=5100（17:19前留报告时间）；不加资源、不改词条、不改RNG、不重置旧策略。QA_IDLE_SALVAGE=1。

必须承认正式恢复的边界：现有CP.restore会重新生成本关战斗，清空scientist_context/reactor_context及active_space_record，闭合并重新基准当前segment；转换本身保留这几个字段，运行确实走上述正式恢复，不能称完整实时战斗连续性。原X1、RNG、调度、busy、tour均保留。当前是图形Godot原生运行，Xorg llvmpipe；不以这里FPS推断RTX3090。

此交接提交时实际运行刚启动，尚不宣称返34/通35成功。运行最终证据将追加，初次错误的manifest JSON分隔格式检查失败已保留日志并修正；对源状态合法性第一次检查误用highestLevel=5作为最大关数，也保留观察者错误，正确生产最大关数为220。
