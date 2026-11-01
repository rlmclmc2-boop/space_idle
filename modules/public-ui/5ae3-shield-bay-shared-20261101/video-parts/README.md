# 原视频二进制分片

来源为 `691a92828e86b15766b8d8e23a83be0580f0bd98:modules/public-ui/5ae3-shield-bay-shared-20261101/shield-bay-shared.mp4`。直接分割原始字节，不转码、不重录。每片最多720KiB，小于768KiB。

按 `manifest.json` 的order顺序拼接各片原始字节，不加分隔符或头；得到原MP4。清单提供总字节数、原视频SHA256、各片偏移/字节数/SHA256。作者已重组并逐字节核对与原视频相同。

命令示例：`cat shield-bay-shared.mp4.part* > shield-bay-shared.mp4`，然后按清单核SHA256。
