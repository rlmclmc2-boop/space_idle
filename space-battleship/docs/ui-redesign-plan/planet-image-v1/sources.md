# P1 来源

唯一设计入口为[game-design/README](../../game-design/README.md)。历史截图仅证明来源，未批准旧布局、旧数值或旧状态。

| 来源 | 固定版本/文件 | 本次使用 |
|---|---|---|
| 共享规范 | [bf359c0d，13 §2.1、§2.1.1](https://github.com/rlmclmc2-boop/space_idle/blob/bf359c0d9073e064f71028958a21a649b3951875/space-battleship/docs/game-design/13-art-interaction.md)；先读8995933e，再核bf359c0d增补 | 仅引用，不修改 |
| M7/V7及S9 | main e93c2212的[planet.md](../../game-design/art/modules/planet.md)和[sources.md S9](../../game-design/art/sources.md#s9) | 星体、探索机、轨道设施的归属和状态 |
| 历史实机 | [573e9312/after/planet-1-start.png](https://github.com/rlmclmc2-boop/space_idle/blob/573e9312f6fd6d9257a5e78aa5588b0403751441/after/planet-1-start.png)；本目录[原图副本](references/historical-planet-1-start.png) | 已直接查看，保留卡通球体身份；不用旧三栏和卡片框 |
| 历史证据边界 | 同提交README.txt：候选ec83d3d、视觉df10eec、基于main29dd17b；原生1372×883；Linux llvmpipe；隔离目录合成解锁状态 | 不能证明自然开放、Windows性能或本图实现 |
| 视觉风格原像素 | [d74d625a/work-equipment.png](https://github.com/rlmclmc2-boop/space_idle/blob/d74d625ade2bea1ffb1fb5f5c93a7dbb685dbb7e/space-battleship/docs/ui-redesign-plan/g1-internal/evidence/g2-quality-r5/after/work-equipment.png)；本目录[原图副本](references/style-equipment.png) | 浅暖、深青、设备体积、文字关系及固定右战场参照；不复制旧模块布局 |
| 球体 | main e93c2212：assets/planets/toon/origin-surface.svg、origin-clouds.svg；scripts/rotating_planet.gd、rotating_planet.gdshader、planet_visual.gd | 现有矢量纹理与着色器，保留独立云层和星体差异；未制作新SVG |
| 设施 | main e93c2212：assets/planets/orbital/models/{auto_explore,refinery,equipment,shipyard}-icon.png及相应.glb；说明见[模型README](../../../assets/planets/orbital/models/README.md) | 已查看四图标，修订回现有双横罐和压床轮廓；未修改模型 |
| 探索机 | main e93c2212：assets/planets/orbital/scout-v1.png；[来源README](../../../assets/planets/orbital/README.md) | 原ImageGen资产，象牙/海军蓝船体、青色引擎；仅参照 |
| 接口候选 | [feat/amount-safe-previews@09af963c源码](https://github.com/rlmclmc2-boop/space_idle/blob/09af963c/space-battleship/src/systems/planet.gd#L228)；91bd955c/372f8499及641d46db/4c1de507均在其祖先中 | facility_facts与automatic候选已实现，父线程确认限定审通过，未合main；不沿用旧文档的待实施/待双审标记，不扩大为UI验收 |

图稿产物来自本线程三次成功的image_gen.imagegen；首次请求因超过5张参照图被参数校验拒绝，未生成图像，随后按工具上限调整为5张。第三次仅按独审意见集中修正进度条、评审标签与状态。没有授权拒绝或绕过。成功请求见generation-requests.json，原始文件SHA-256见provenance.json。图中的设施是模型身份参照下的生成表达，不声称与原GLB逐像素一致。原始探索/设施图标无需复制，固定main基线可恢复。
