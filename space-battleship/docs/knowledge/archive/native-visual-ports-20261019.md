# native-visual-ports-20261019
基准2943101f，原分支。目标：闭合原生保留呈现视觉炮口映射，优先GDS/Shader；数值发射点、原生ABI与C++/DLL不变，不扩截图矩阵。
定位：battle_slice_runtime.gd:on_event/consume/spawn_visual，retained_beam_foreground.gd:sync，battlefield.gd:visual_muzzle/_numeric_launch_origin，retained_flights.gdshader及GPU联系人shader。
缺口：需确认原生事件的mount/ordinal/launch字段和保留flight材质是否具备发射源识别信息；仅扩读相应事件消费与只读拓扑字段，不构建原生。
下一动作：分离视觉事件起点与数值launch；针对实际接口做必要的夹具检查，若ABI内缺少映射所需信息则先回报。

结论：持续光束已有GDS owner.visual_muzzle入口。其他发射反馈on_event含slot/serial，可在GDS事件层单独适配；但紧缩脉冲 retained row[12] 只有变换、kind、分拆时钟/速度，无mount/serial，GDS出生事件无法与绘制实例可靠关联。advance_retained优先source.fixed_ray并使用数值ray_origin/ray_step，register_visual/bind_visual无法覆盖该分支。Shader/GDS精确逐弹映射缺少必要数据，禁止按邻近位置猜槽或关闭紧缩保留路径替代。
需要父确认的最小后续动作：修改原生呈现生产器以携带source-slot标识（可复用现有custom通道、保留公开ABI）或支持独立visual-ray覆盖；两者均需原生源码改动及重编。未执行。此次仅只读数据流检查，游戏代码/原生源码/ABI未改，无新截图或运行测试。任务暂停在原生呈现接口缺口，非权限拒绝。
