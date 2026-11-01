# 反应堆局部受光与炉池实体出口

运行源 `implement/reactor-centered-godot@cdd8b494b96929c2c965f2284519d294ebf3d13a`。当前依据为M3及批准稿`24db2a9c:modules/public-ui/unified-abstraction-proposal-20261101/whole-game-style-concept.png`。这是原图还原制作检查点，未作独审、用户或整页完成宣告。

## 读取与安装

先看`reference-runtime-comparison.jpg`、`four-active.jpg`、`single-active.jpg`和`author-review.md`。1/2/3/4路真零及均分正载图以`single/two/three/four-{zero,active}`命名；两段`*-12s.mp4`为本源1440×900正常1×影片，每段300帧/25fps，`*-phases.jpg`覆盖全12秒每0.25秒。2/4/8秒原帧另存；完整解码及帧数见`video-probe.json`。影片前1秒真零，随后原生均分，约5秒点原生暂停1秒再恢复。2秒可能仍显示真实“供能已更新”短反馈，未伪造隐藏反馈；当前无引导遮核心。

`installation.json`给私有替换清单；按`source-closure.json`消费同版Stage/Scene/GLB/layout/全部材质与独立体积资产，不能漏`faceted-work-common.gdshaderinc`或`faceted-plasma-work.gdshader`。压缩闭包同时提供小于1MiB顺序分块，拼接哈希须一致。全部媒体和源码闭包hash见`manifest.json`。不覆盖公共宿主、Owner、装备或配置。

## 覆盖边界

四路为真实Session/Owner接口，开放与钱包受控。少路通过真实Reactor类的受控`reactorModules`及测试接纳发布器装入原UI，不是自然流程，也不证明少路Session跨系统因子发布。原生轨道鼠标命中50%、真零、均分及1/4暂停恢复有日志；本轮没有新增购级/MAX或完整极端状态矩阵。端口/安装帧误差仅证明坐标一致，不代替美术判断。当前顶部仍是本地旧宿主，对应最终公共壳组合需另接固定源。

本轮GLB/生成器/metadata同步；ports/export/import日志绑定当前资产，几何核对不冒充美术通过。

性能与剩余项见`performance.md`和`author-review.md`。本轮没有新FPS收益结论，不合main。
