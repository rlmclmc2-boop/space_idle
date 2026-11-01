# B01反应堆制作交接

制作要求与完成标准见[M3](../../../../game-design/art/modules/reactor.md)。

## 当前版本与下一项

执行分支`implement/reactor-centered-godot`，文档源`966a9132569d52ce9a1e641c1845f69c091a8371`，运行源`f7d3d055`。炉池至排液管的连续下降槽已接入。

下一项：判断并调整完整整页下料嘴→承接池→排口的热流、受约束盾场体量及四设备/核心/舱室材质关系；按M3完成标准继续制作。

## 当前证据索引

[同版归档2118e321](https://github.com/rlmclmc2-boop/space_idle/blob/2118e3218e3016933c8a33c4f70afb111761d68c/modules/reactor/direct-sluice-20261101/README.md)：作者自查四路均分25%工作/真零整屏及正常1×10秒250帧视频。独立整页视觉与目标硬件性能结论尚未取得。

## 恢复

资产/脚本位于`assets/ui/reactor/b01/`，端口与裁图读同源reactor_ports.json。使用本地Blender4.3.2、Godot4.7.2和Python/ImageMagick；工具持续免费且无生成次数配额。恢复固定源和现场WIP时保留仍被运行引用的舱室、核心、夹具及控制台。
