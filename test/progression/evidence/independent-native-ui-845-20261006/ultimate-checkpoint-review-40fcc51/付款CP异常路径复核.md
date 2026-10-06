# 40fcc51付款CP异常路径复核

真实稀疏checkout HEAD=40fcc51a8b20aa51f2cc683eda6b57490d685e70，干净。相对1f12b38仅longrun.gd及新增59行存档专项变化；生产规则、价格、究极链策略未改。沿用已读AGENTS/TEST相关规则。此次只读代码；父执行针对性fixture，我未启动游戏、付款夹具、长跑或修改候选。

## 两项原发现已修正

1. ultimate_checkpoint_name(:54–56)包含付款时保存的round、目标机SHA前16字符、command_seq、operation；click_button的pending entry保存完整round/drone/seq/op。重铸后的同seq不同round不再撞旧轮档，实际支付仍绑定完整ID，不因档名选择其他机。
2. checkpoint_now(:65–71)先Checkpoint.write主checkpoint.bin，成功后才write_once步骤档。因此附属档案错误不再阻止当前付款状态/chain phase/receipts/RNG/controllers先落到主CP；原1f12b38的“已付款但主CP仍旧”附属写失败路径已消除。

## 异常停机与pending的准确含义

- 主CP写失败：恢复内存reforge_pending和ultimate_pending，设置checkpoint_io，记录错误return，不尝试历史档。下一while条件有input_failure即停，不再执行下一付款。旧主/backup可能仍可读，但不得称新付款状态已落盘；IO完全不可写时当前状态不能凭空持久化。
- 主CP成功、究极档失败：当前已付款主CP有效；恢复内存ultimate_pending，设置ultimate_chain_checkpoint_io并return。正常循环不会再派下一游戏动作，finalizer可能再次尝试保存和档案，但不推进game.tick。
- **pending只保留在内存**：:62–64先clear队列，再capture，所以主CP中的pending为空；档案失败后才恢复内存队列。不能写“失败档案意图已持久化、重开会自动补写”。第一次主CP保存也早于产生本次input_failure；正常finalizer重试会把错误收入后续主CP。专项仅调用checkpoint_now，没有覆盖整个runner的最终收尾/重启。
- 同身份档案已经存在，仍用write_once报ERR_ALREADY_EXISTS并停机，不覆盖旧档。当前设计是保守报错停机，不是验证已有有效档后幂等继续；这是明确行为，不再造成丢失新付款状态。

只有ultimate档失败分支恢复ultimate队列，reforge队列若同时非空则未在该分支恢复；正常有限链每次单一付款并立即保存，未发现实际两种队列并发的运行来源，故此不扩为当前实测故障。主CP已含当前游戏状态，两队列的磁盘重试意图仍均为空。

## 专项覆盖及未冒称的范围

新增test_ultimate_checkpoint_safety.gd是无tick、无新付款的存档fixture，读真实已付三步CP。覆盖不同round/目标档名、占用档名、缺少历史档目录、主路径失败：核当前付费phase/3 receipts/material/core保留，旧历史档不改，backup有效，内存pending和错误种类。它明确验证pending in memory，未断言磁盘pending，未试重启后自动恢复/补写。

父已从28851dd三个原始CP核实真实三步支付成功，这是成功路径证据；不能替代本次IO异常fixture。父负责读取专项执行结果，本线程没有重复执行或把源码断言当已通过结果。

结论：我指出的跨轮命名冲突及附属档先写导致主CP滞后已在代码真实解决；存储失败保持报错停机并在内存保留重试意图，语义有明确边界。主写失败不承诺新状态已保存，附属失败不承诺重开自动补档。未扩大到数值、视觉或新的进度测试，原35终态文件保持不变。
