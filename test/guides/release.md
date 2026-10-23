# 构建与发布

| 修改范围 / 目的 | 按需入口 |
|---|---|
| Windows 单 EXE | `build_release.bat --no-pause`；构建器自动运行 `verify_release.gd`，后者不经 `run.py`、不进入最终 EXE |
| 构建失败保护 | `powershell -NoProfile -ExecutionPolicy Bypass -File test/test_release_failures.ps1` |
| 跨路径迁移 / 发布文案 | `python test/test_release_portability.py` / `python test/test_ui_text_release.py`；从工作区根直接运行，自建隔离目录，不经 `run.py`。迁移测试需 Windows `subst` |
| 发布字体 | `python test/run.py test_release_font.gd` |


S3 构建输入由 `configuration_snapshot.ps1` 在同一 OS 锁内捕获，之后只暂存捕获字节。便携构建测试可用 `SPACE_BATTLESHIP_TEST_GODOT`、`SPACE_BATTLESHIP_TEST_TEMPLATE` 指向已有测试运行时；测试只复制到 `test/work`，不修改正式安装。`verify_release.gd` 核对当前发布外观集合和原生准入，不依赖历史外观数量。
