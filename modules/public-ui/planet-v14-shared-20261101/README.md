# v14星球最终共享组合附件

运行源 `079f2ec95df871711bbb32931b027373a9c30e12`；原组交接 `23b5e91e875815c8dd2481531a77f0004a11434f`，资产38315226。四GLB与planet_orbital_spine共五件逐blob同源；panel与e7591438相同，公共宿主、导航、主题、操作台和装备保留。

推荐附件顺序与SHA见`delivery.json`：

1. `planet-overview.jpg`：总览，1440×900。
2. `planet-facilities.jpg`：装备工坊详情及三段门板，1440×900。
3. `planet-v14-shared-1x-6s.mp4`：当前公共宿主同版6秒待机动态。

另有人员/征服展开两张完整JPEG、四张原PNG、作者结论、源码blob、运行驱动及日志。四张JPEG保持1440×900、4:4:4、各小于1MiB；无画面改绘。MP4为30fps/180帧，Godot MovieMaker固定步长离线生成、展示层1×，未插帧；帧区间126..306，元数据见movie-segment.json。`video-parts.json`提供每件小于768KiB的分片顺序及完整/分片SHA256，拼接`video-parts/part-*.bin`还原视频。

作者已看四整屏、180帧总览及7原尺寸关键帧，结论为当前整页与待机动态具备本轮用户评价条件，详见author-review.md。本次只做最终资产组合及所需采证，未重开完成的UI验证或扩大制作。导入/运行未见脚本或资源错误，VSync是软件驱动既有提示。当前未合main；由父级实际发送附件。
