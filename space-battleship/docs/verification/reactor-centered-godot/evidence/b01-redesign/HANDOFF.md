# B01反应堆制作交接

制作要求与完成标准见[M3](../../../../game-design/art/modules/reactor.md)。

## 当前版本与下一项

执行分支`implement/reactor-centered-godot`，运行源`5ae32e283a59dfa35886d63a94fb74df7568b15b`。炉池至排液管由同源顶点形成连续下降槽，液面工作光限定在槽内。盾场展开及边缘光改读实际场壳透明轮廓，移除重复程序外圆弧；投射鞋仍前遮。四机使用同一对舱室长条冷暖反射灯重渲，接口/业务/布局未改。

下一项：在同版公共组合中复核整页材质、盾场体量与主次。当前大面受光变化较轻，材质统一仍待整页判断。公共宿主由整体组接入上述固定运行闭包。

## 当前证据索引

[同版归档41b38ef0](https://github.com/rlmclmc2-boop/space_idle/blob/41b38ef00d6f2eb6cbf003a16972088eea040e22/modules/reactor/direct-shield-bay-20261101/README.md)：作者自查模块分支临时宿主中的四路25%工作及真零整屏、2/3/4/5/9秒原尺寸图、正常1×10秒250帧视频及整页时间样本。Godot4.7.2导入及运行无脚本/Shader错误，作者观察场壳与前层机件关系稳定。本版独立整页、用户审核、其他少路状态及目标硬件性能结论尚未取得。

## 恢复

资产/脚本位于`assets/ui/reactor/b01/`，端口与裁图读同源reactor_ports.json。使用本地Blender4.3.2、Godot4.7.2和Python/ImageMagick；工具持续免费且无生成次数配额。恢复固定源和现场WIP时保留仍被运行引用的舱室、核心、夹具及控制台。
