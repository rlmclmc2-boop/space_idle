# 4–7关新科技树适配

状态：实现与定向headless验收完成，待父审及独立GUI新档评测。基准 `c66190090c3bded4e09beb347acad59e589910c2`。范围仅4–7关敌表/编队/资源预算、正式敌名及表投影；不改前三关、异空间本体、科技树机制、个人存档。

源：`config_excel/mon.xlsx`、`monGroup.xlsx`；生成：`data/game_data.json`；解析：`tools/import_workbook.py`。风险：GUI敌情版面由另线程修订；新AI教程后置。证据：`test/evidence/stage4-7-polish-20261017/SUMMARY.md`。下一步父审diff，之后两位独立评测与父在正常新档实玩1–7。
