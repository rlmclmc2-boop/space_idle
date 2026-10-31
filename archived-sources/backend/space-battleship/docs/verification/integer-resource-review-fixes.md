# 资源整数候选：两处原审退点修复

固定修复基线`a83ad9c83aebdfc18ac98f4f784aeb16eca16da4`，该基线经Astra审核未通过。本次用户明确允许原后台线程修复两处并做对应必要验证，不新开任务、不重构保存系统。**修复及资源消费最新固定版`feat/amount-safe-previews@f9244a30ad1843128aaa0a620c4dc3e4866685b2`已普通发布，根协调线程确认同一Astra high限定只读复核通过：非法奖励键在restore/Claim前拒绝、完整候选钱包前校验；chrono按请求窗口比例还原支持秒数，关闭超过1秒的截断退点。91项是作者证据，非独立复测、完整游戏或main验收，未合main。** 消费者按各自既有依赖精确合并，不用旧树覆盖新UI、不停止其他制作。 唯一规则入口仍为[设计README](../game-design/README.md)及[资源契约](../game-design/contracts/resources.md)。

- 奖励键/领取：Resources.valid_id统一原String非空规则，whole_map/progress_map及Hyperspace._whole_resource_texts复用；非法材料键在恢复候选规范前即拒绝。Session._hyperspace_credit先验证奖励键/金额，并对完整候选钱包执行与accept_budget相同whole_map。所有候选验证在Claim/native接纳之前完成。prepare_claim/accept_claim、Claim/native顺序与故障语义保持；不只调换钱包/Claim顺序，不把合法无变化false当失败。无效候选不进accept_budget，不置Claimed、不扣/加资源、不改变RunState；原文件不改。
- chrono长窗口：_accept_real_time在零秒提前返回；不足时用to_ratio(Amount支持时长,Amount当前请求秒数)得到有界比例，再乘当前请求秒数，不再将超过1秒的时长压成1秒。金额、可支付比较与除法继续Amount，只有被当前请求窗口约束的时长比投影到有限seconds。预付服务进度/原支付接纳保持；不改通用Amount、native或保存事务。

[单个对应探针](../../foundation/tests/_integer_resources_review_probe.gd)使用实际Session/native与同一生产配置，91项全部通过：空键、负数、非法Amount三组CompletedPending恢复候选零接纳；绕过恢复的恶意Pending在claim_hyperspace拒绝，重试仍无变化；合法奖励只兑付一次；合法零奖励的未变化钱包仍成功Claimed。使用规范有效基线及var_to_bytes验证非法NaN输入前后零变化，避免NaN不自等与规范类型变化的误判。

真实Session.frame无暂停/离港：chrono余额5、倍率2，一次10秒与10×1秒均实际扣5，game_time+pending_seconds=15；明确计入原64步执行预算留下的已付时间，不把尚未执行的pending丢弃。另核余额0/5/10的10秒窗口接受10/15/20、相同扣费、零秒无状态变化；2.5秒后pack/unpack并initialize新候选，再接受7.5秒总计15且扣5，未写用户存档文件。main check-only退出0，正式日志无ERROR/WARNING。首轮快照断言的夹具误判不计正式证据，未放宽生产校验。

[清单与原始日志](integer-resource-review-evidence/manifest.json)固定源/基线/配置/DLL hash。仅3个生产GD修改；完整源差异基于a83逐方法记录，不修改UI、Excel、C++或M10。消费者接口字段没有新增变更。未重跑无关290/61范围，不声称完整游戏、native故障组合或保存系统验收。M10原hash与179/262元数据保全；本接替尚未实际压缩。
