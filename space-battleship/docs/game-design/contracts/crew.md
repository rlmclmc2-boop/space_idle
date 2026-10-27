# 船员前后端契约

[回唯一入口](../README.md) · [版本与共同边界](../14-ui-contracts.md#1-版本与使用边界)。本分册为本模块唯一契约正文；保留原第14章节号及原版本状态，不表示实现或合入状态升级。跨节“本页第N节”依[共同页索引](../14-ui-contracts.md)定位；第4–6节接纳/通知/本地状态约束一并适用。
[本组版本状态、共同身份与失效边界](../14-ui-contracts.md#8-已审待实施成员设施与选中节点的最小只读事实)。

## 2. 主线现有模块连接

| 模块 / 前端 | 公开状态读取与必要操作输入 | 操作、提交与结果入口 | 变化通知或现行刷新 | 前端本地状态归属 |
|---|---|---|---|---|
| 船员：crew_panel | Crew `member_options/status_rows/job_options`；Planet/Galaxy `assignment_options` 提供任务身份；Planet `assignment_capacity`、Galaxy `assignment_admission`为各自领域端口 | Session `coordinate_assignment(member_id,kind,target,...)`；保留唯一占用与原协调结果 | Crew `members_changed(ids)/options_changed`；Planet `assignment_options_changed/availability_changed`，Galaxy `availability_changed` | 选中成员、派遣候选与筛选/滚动。按kind/target关联任务，不能越权读目标私有账本。 |

## 3. 候选展示扩展与尚未补齐的交换

| 模块 | 候选已实现、未合主线 | 尚待补齐/审核 |
|---|---|---|
| 船员/星球 | Crew `assignment_count(kind,target)`；候选页面将人数事实接入星球详情并订阅成员变化 | 目标人数/容量/任务进度的充分关联展示；各目标模块提供自己的公开事实，不新增通用任务账本。 |

### 8.2 Crew：成员事实

拟增`Crew.member_facts(ids: Array = []) -> Array`。空ids按现有成员选项顺序返回当前可用成员；显式ids只查询这些配置成员，未知id不生成行。显式查询已知未开放成员时，只返回`id/name/available=false/reason="CrewLocked"`，不伪造其可用人物状态。该接口不负责选出“下一个解锁成员”或新增开放门槛算法。

| 必需字段（可用成员行） | 类型、单位与来源 | 消费边界 |
|---|---|---|
| `id/name/available/reason` | String/String/bool/String；成员配置身份、原可用性缓存；可用行reason为空 | 名称是纯配置名，不从member_options的格式化名称拆等级。available不是任意目标派遣已获准。 |
| `level/experience_enabled` | int/bool；实际等级及既有`experience_enabled()`事实 | 等级不加1或套演示等级；经验功能未开放不展示虚构进度。 |
| `experience/experience_required/experience_fraction` | 经验点数的Amount文本；下一等级所需Amount文本或null；有限[0,1]或null | experience为已扣除已升等级费用后的实际余量；required复用现有单级经验求值，fraction由Crew经Amount生成。功能未开放或现有等级范围已无下一等级时，required/fraction为null，不新增等级上限规则。 |
| `kind/target/mode` | String/String/String；现有唯一占用记录 | kind沿用空闲空串、system_job、planet_explore、planet_build、galaxy、hyperspace；target保持现行含义，mode沿用1/10/max。展示不拆中文岗位串，不将一份成员复制为多个占用。 |
| `reservation_reason` | String；无保留为空，在线任务保留沿用`HyperspaceCrewReserved` | 只提示普通派遣/释放受限；停止/领取仍走对应在线任务入口，目标合法性与容量仍由既有准入和命令确认。 |

成员事实不承诺按单人等级计算岗位的聚合增益、未来岗位收益或动态战斗乘数。已有成员/岗位选项与派遣命令保持原入口。

### 8.5 本模块通知

[共同失效边界与版本状态](../14-ui-contracts.md#8-已审待实施成员设施与选中节点的最小只读事实)
- Crew沿`members_changed(ids)`使对应成员事实失效，沿`options_changed`更新可用成员/功能状态；经验变化、真实占用/在线保留与释放须在原接纳完成后覆盖对应id。查询不得发这些信号。
