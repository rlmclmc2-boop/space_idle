# 第六段候选入口（未合 main）

第六段执行范围来自 `4dc31e949fae3e57f5ace659380cc3fc23869b31` 的本文件，代码基准 `d71bd1d26d9d3a5005a891b684de531966fdab1c`。

当前候选：`refactor/stage6-retire-history`。唯一交接：[第六段范围、科研恢复定位、验证及保留事项](knowledge/archive/stage6-retire-history.md)。原始证据和删除分组统计由该交接链接定位。

双审三项 runner 修正提交：`6b5864031d927bab23b69ec4d54e20f0e831a305`（相对原候选 `25b08f754e89b6c707ce54ff45611f6c8b19d4ba`）。仅显式保留生命周期 probe 并匹配 `GEOMETRY LIFECYCLE`，识别船员性能完整 40 场景摘要，将 Python 宽泛 passed 判定改为按入口的完整终止摘要。原临时核对补充后 **33/0**，结果见交接的“双方审查后的三项 runner 修正”对应章节；未新建测试项目、未重跑游戏专项。旧 high 已压缩停止，等待接替 high 与 dot 复审；本入口更新仅记录上述修正提交。

仅交 dot 与现有 high 双审，不合 main；本入口、交接及证据仅在候选分支。未经新范围确认不得继续扩删或修遍历史探针。上下文开始压缩即保存交接并停止。
