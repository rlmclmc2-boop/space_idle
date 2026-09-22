# 发布字体

- 来源：[Google Fonts / Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc)。`NotoSansSC.ttf` 为原始可变字体，许可见同目录 OFL.txt；许可随 PCK 内嵌。
- `NotoSansSC-Regular.tres` 使用 OpenType 数值标识 2003265652（wght）固定字重400，供发布版绘制及 UI 主题共用。当前引擎对资源中的字符串键未生成实际变体，会回退到字体默认极细字重100；不得只检查配置字典，发布验证读取 TextServer 实际字重。导入配置关闭系统字体回退，开发版仍用原有 SystemFont。
- 字体作为仓库资源直接构建，不要求构建者或玩家安装字体，不在打包过程中在线获取。
- 标题符号等使用同仓库的 [Noto Sans Symbols 2](https://github.com/google/fonts/tree/main/ofl/notosanssymbols2)，作为内嵌回退字体；对应许可 NotoSansSymbols2-OFL.txt 同样进入 PCK，运行时关闭系统回退。
