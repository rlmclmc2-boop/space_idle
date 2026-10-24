# architecture-native-20261024
目标：按用户要求重选直接顺序执行结构；仅设计、不实现。
基准：e3e5e92b82e22d8fdca63ff11f59ebfc5dbe7e51；原main事实基准b4729b9a9803458b5ac19a4945c2fe0d5f76e51f。
分支：design/game-architecture-from-main-b4729b9。
完成：重写README/05/07，统一01～04/06/08；09配置附录原样保留。
结构：GameSession具名同步函数；SpaceCombatKernel唯一战斗状态及完整规则；共享C++ Amount；同native headless测试；文件保存独立串行。
定点核查：combat_execution_kernel.h的Actor/Weapon/Attack/Instance/Flight/Timed/Defence、advance/feedback/configuration和presentation；native_execution_compiler/session的支持限制及旧波次交接。缺失分支/五传说、连续波次、手动超空间明确并入同核。
保留：玩法公式、26正式根工作簿/46sheet附录、已核清参数与边界；待决D01/02/03/04/05/07/08/10八组。
验证：十篇Markdown相对链接/围栏/决策引用检查通过，旧泛化框架与双后端残留搜索零命中，git diff --check通过；父线程独立一致性检查完成。
范围：仅方案文档及自身归档，未运行游戏测试，未改游戏/Excel，未合main；设计仍待用户审阅后才能实施。
