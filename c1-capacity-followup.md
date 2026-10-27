# C1容量裁定同步

代码：`rewrite/ui-review-followup@b7bb3de3`（在50ed7cda上增加一项来源修正）。五舰无人机容量按用户裁定为1、2、3、4、5。

权威Excel `config_excel/hyperspace_config.xlsx` 的“舰型容量”表本来就是 hull_id 对应1–5，基础参数 maximum_equipped=5为独立全局硬上限。`ship.xlsx` 的 para_5实际为战舰占地1/1/2/2/4，para_6是同种武器上限999，不是无人机容量。旧Campaign误用para_5作为drone_capacity。

修正仅在Campaign初始化读取现有权威舰型容量映射，并由ship_facts.drone_capacity返回。Session配装、预设、成长/改造刷新、换舰截断以及Battle/native admission原消费链不另建容量规则。全局上限与舰型上限仍同时生效；不硬编码12345，也不改原工作簿、占地、同种武器上限或maximum_equipped。

验证：生产Excel发布入口对当前29工作簿验证成功，发布的容量为1–5；未修改Excel。capacity-probe在真实Session/native中逐舰装备N架成功，N+1拒绝且保持原装备；5架换回护卫舰截断为1架；传入假容量999仍被全局5拒绝；复制配置改Destroyer容量为3时Campaign返回3，证明消费表而非写死常量。最终日志退出0、无SCRIPT ERROR；平台证书存储读取错误单列。

本轮没有GPU重拍或C4运行测试。probe与出版验证报告附于capacity/；不包含完整生成JSON、存档或DLL。原A1–A7证据仍对应50ed7cda，不冒充对后续全场景的新验收。
