# 当前 UI 制作与历史规划入口

设计唯一入口仍为[game-design/README](../game-design/README.md)，当前固定版本/跨组状态统一见[11](../game-design/11-stage6-contract.md)。本页不再维护第二份阶段台账。

## 当前推进方式

按最新获准方向在各自原分支完成一个整体交付，逐模块制作但以完整页面与共用宿主关系判断。R3共同风格已获准推进实机；装备/B01待消费公共包，星球整体形体仍制作。方向批准、源码接入、局部证据、整页审结分别记录，均不等于合main。

结构/状态/资产标准见[13](../game-design/13-art-interaction.md)，业务与模块边界见[14](../game-design/14-ui-contracts.md)，复查/报告方法见[07](../game-design/07-verification.md)。前端不改Owner规则，不用旧候选要求恢复已退回的组织。当前桌面宽屏目标；窄屏仍排除。整页视觉不是问题清单清零。

每组入口只维护：整体目标、批准依据、固定源码/证据和现场时间、当前具体一步、完成标准、下一独立项和未完依赖。新决定替换旧生效文字；详细过程移历史并给稳定问题索引，不叠“当前状态”，不指示“末几节”。历史只在出现对应问题时读取。

当前制作不因局部候选送审而全部停下；确需用户决定的项列清来源/影响并等待，其他独立项继续。冲突不以旧main、最新实现或某次局部通过代选；见[裁定清单](../game-design/review/conflicts.md)。不创建新的审查任务或独立复测线程。

## 当前各组入口

| 组 | 唯一当前交接 |
|---|---|
| 整体/公共源 | [R3与公共壳](shared-host-shell/runtime-clear-zone/README.md) |
| 装备 | [逐槽R3](../verification/equipment-hangar-godot/workbench-optical-revision/inline-slot-workbench-concept/README.md) |
| 反应堆 | [B01新结构](../verification/reactor-centered-godot/evidence/b01-redesign/README.md) |
| 星球 | [R17整体](../verification/planet-single-side-godot/visual-r17-curved-spine/README.md) |
| 后台 | [资源整数契约](../game-design/contracts/resources.md)与[各模块合同](../game-design/14-ui-contracts.md#2-主线现有模块连接) |

## 按需历史

[G0坐标/输入依据](g0-frontend-constraints.md)和[G0全系统范围准备](g0-system-coverage.md)保留其固定基线；只在核对应映射/范围问题时读，不是当前阶段状态。全系统覆盖仍不能靠局部样板代替，但早期多方案选型的G0–G5状态不能暂停已获批准的现任务。

[早期规划原文](HISTORY.md)保留比较方法、覆盖矩阵、旧阶段门槛和职责；[更早退回候选](../ui-design-candidate/README.md)仅供追溯。旧“G0仍未通过”“尚未选定任何UI”“先等新图再恢复”不再从当前入口下发。

## 旧章节迁移

原第1–10节及依据全部保留在HISTORY同名锚点；下列别名仅保持旧链接能到达迁移说明。
<a id="1-交付目标与边界"></a><a id="2-先核实约束再展开候选"></a><a id="3-实质不同的判据与共同设计模板"></a><a id="4-全系统覆盖表每份候选都必须完成"></a><a id="5-共用状态与跨系统连续操作"></a><a id="6-资产安装与-godot领域契约映射"></a><a id="7-执行阶段与交付门槛"></a><a id="8-双审独立找反例并相互挑战"></a><a id="9-职责分工与交接"></a><a id="10-最终完成门槛与当前状态"></a><a id="依据与阅读边界"></a>

旧正文从[历史目录](HISTORY.md)按相同标题定位，不再作为当前执行清单。
