# rewrite-stage2
入口：a815d2a 的 docs/game-design/README.md；07第2步；第1阶段终点ca676e0e已双审通过。
分支：rewrite/stage1-foundation；不合main、不另开线程。
范围：GameSession直接同一native核，静态输入/历史动态、四武器、命中、连续波次、航行与掉落。
定位：01运行/02命中/03属性组合/05第5节/06Amount；native combat_execution_kernel.h及直接表现头；runtime/及tests/run_cases.gd。
缺口：现核2972行仍double金额、2^53历史预检，configure清所有战场；需在同核迁移与连续波次API，不能第二套战斗或双账本。
下一步：共享Amount操作适配和evaluate_module；逐段接核与真实GameSession/独立Excel用例。
停止：本阶段审核前不进第3步；上下文开始压缩即停止并交接。

已落地：共享evaluate_module/绑定；同核Amount金额与int64历史；start_wave/finish_wave/take_results及撤退生命周期。
验证：重建DLL，14 Amount+6四武器/命中/大数用例+W01跨波/掉落去重通过；Amount原生测试通过。
下一步：GameSession、静态装备组装、航行/驻守/撤退、经济拾取及可运行入口；阶段未完成。
