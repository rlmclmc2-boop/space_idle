# 实际环境、来源与复用

本候选真实运行于 **Godot 4.7.2.stable.official.ed1daf0bf**，Linux x86_64、Xorg `:99` 1440×900、OpenGL compatibility / Mesa llvmpipe。下载官方[4.7.2 Godot builds release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)，zip的SHA512与同release官方`SHA512-SUMS.txt`逐字一致。程序、zip、API、库、构建输入和配置hash见[environment.json](environment.json)。

程序在 `/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64`；没有替换系统旧4.6.3。4.7.2导出的单精度 `extension_api.json` SHA256为 `d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986`，与工程正式构建脚本固定值完全一致。复用现有外部 `/tmp/space-idle-godot-cpp`，实际HEAD `507ed9d840c01a3c5b2a39af8bb4000bfac30bf5`，没有clone项目/新建工作区。

## Linux 本地构建

原生源码逐字节复制到 `/tmp/space-idle-native472/src`，沿用工程SConstruct及原有受限class profile（只裁剪不使用的绑定）。构建时加入两项Linux链接选项：

```python
env.Append(LINKFLAGS=['-Wl,-Bsymbolic', '-Wl,--exclude-libs,ALL'])
```

实际命令在 `/tmp/space-idle-native472` 执行：

```bash
PYTHONPATH=/tmp/space-idle-python-deps python -m SCons \
  bindings=/tmp/space-idle-godot-cpp platform=linux arch=x86_64 \
  target=template_release \
  custom_api_file=/tmp/space-idle-native472/extension_api.json \
  build_profile=/tmp/space-idle-native-linux/profile.json -j 4
```

产物 `/tmp/space-idle-native472/bin/libspace_native.so`，扩展清单 `/tmp/space-idle-native472/space_native.gdextension` 指向该库，兼容下限仍4.7。构建日志与清单文本在 `evidence/`。

首次不加链接隔离时，在Crew初始化调用Amount的路径中SIGSEGV，栈落于静态libstdc++正则/流相关代码；[原始失败日志](evidence/native-initial-crash.log)保留。增加上述本地链接隔离后重新链接，正式main/Session/native实际启动及全部定向操作均成功。现象与Linux静态C++运行库符号互置一致；此处是本地构建处理，不把推断写成业务修复。没有修改native源码、正式Windows构建脚本或用旧API降版本。**这不是Windows正式DLL构建/运行验证。**

## 同环境最小启动

从 `/workspace/space_idle/space-battleship`，先按原发布器生成本地配置，再导入资源并启动：

```bash
PYTHONPATH=/tmp/space-idle-python-deps python foundation/import_excel.py

export XDG_DATA_HOME=/tmp/space-idle-runtime472/data
export XDG_CONFIG_HOME=/tmp/space-idle-runtime472/config
export XDG_CACHE_HOME=/tmp/space-idle-runtime472/cache
export DISPLAY=:99
export SPACE_IDLE_NATIVE_EXTENSION=/tmp/space-idle-native472/space_native.gdextension
export SPACE_IDLE_SETTINGS_PATH=/tmp/space-idle-runtime472/settings-manual.json

/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64 --headless --editor --path . --import
/tmp/space-idle-godot472/Godot_v4.7.2-stable_linux.x86_64 --path . --resolution 1440x900 --position 0,0 --audio-driver Dummy
```

这些XDG路径用于本机可写工具数据；没有改HOME或用户真实存档。`SPACE_IDLE_SETTINGS_PATH`必须为复测者自己的本地设置路径，首次正常启动会建立独立默认存档；不要指向用户个人数据。音频Dummy仅因本机无音频设备，未删音效功能。屏幕已存在，实际[Xorg配置](evidence/xorg.conf.txt)保留，可供同机缺屏幕时重用。Godot未传max-fps或固定帧数设置，VSync在dummy驱动上不支持的警告原样保留。

所有者/战斗/素材仍由真实主场景读取；没有浏览器替身。验证驱动文本分别保存为`evidence/capture-driver.gd.txt`、`performance-driver.gd.txt`，它们只用于本次可追溯取证，不是生产测试入口或业务fixture。绘制截图直接取Godot根视口纹理，没有程序拼图。

工程`generated/config.json`、验证JSON、库、工具安装、临时存档、`.godot`缓存和编辑器生成的额外`.import/.uid`均不提交。提交包含的新增机库PNG导入设置仅为该新素材。原正式Windows启动路线仍以foundation入口为准。

同机快速复用：本轮最后一次运行使用的未跟踪编辑器元数据已归档为 `/tmp/space-idle-runtime472/import-metadata-d2bb4cb9.tar.gz`，可在项目目录先 `tar -xzf /tmp/space-idle-runtime472/import-metadata-d2bb4cb9.tar.gz` 恢复本地导入元数据，避免再次扫描旧证据图；仍须采用正式导入路线。该本地缓存的hash在environment.json，不是Git交付或权威资源。
