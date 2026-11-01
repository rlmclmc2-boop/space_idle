# 星球建筑与环整体概念稿

这是独立生成的建筑与环结构，不引用 `facilities_v5/v6` 的网格。当前设计采用建筑嵌入环的舱段关系、细连接梁与大枢纽比例；继续沿用已认可的整屏分面装甲语言，依据见 `archive/design-docs-before-cleanup-20261031@24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/`。

细环从四设施主体的承力墙内穿入穿出，各设施沿环向延展成独立舱段。空间站以指挥核和两翼居中，精炼厂以中央压力炉及两侧进料段居中，工坊由长侧承力墙和错层屋顶围住制造槽，船坞的环段向外分叉为敞开的泊位。青色只表示服务与能源，暖橙只表示热工和作业。

`build_concept.py` 以 Blender 4.3.2 和已有星球表面贴图生成独立场景与 1600×900 主构图。`concept-complete.png` / `.jpg` 呈现完整主剪影；同源 GLB 还需在游戏实际页面、独立建造阶段和转动中核对。当前为结构候选，不是用户终验。

`export_runtime.py` 从本目录的 `concept.blend` 导出 `assets/planets/facilities_v8/` 四件新 GLB，不读取旧建筑网格。四设施保留既有运动枢轴名称和业务 ID。运行时环只保留穿过舱段的细承力梁，宽截面由各设施资产自身承担；轨道角度、独立建造段和球后遮挡继续由 Godot 控制。
