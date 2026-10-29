# 概念图生成记录

以下图片由 `image_gen.imagegen` 生成，`transparent_background=false`。每张的实际提示词为“共同前缀”直接接相应“类别续句”（前缀末尾已有空格）。图像是探索候选，不是经过 Godot 渲染的运行截图。生成前实看了 [R5 四设施页面](../../../../verification/planet-single-side-godot/visual-r5/fit/all-four.png)、[R14 实机](../../../../verification/planet-single-side-godot/visual-r14-full-turn/evidence/post-fix/right/key_0012.png)及[现有固态表面图](../../../../../assets/planets/painted-v4/surface.png)，并核对[M7](../planet.md)与[全局美术](../../../13-art-interaction.md#21-专属资产统领构图与观看)。这些参照没有作为工具输入图片，只用于编写提示词。

共同前缀：

> Create one landscape TWO-PANEL game environment concept sheet. Left panel: the celestial body alone. Right panel: EXACT SAME body, same scale and camera, with a COMPLETE INTEGRATED FACILITY SYSTEM. The celestial body is about HALF the panel height; leave generous dark space all around for large, readable facility structure. No text, no labels, no UI, no interface mockup, no boxes. Hand-painted 2D stylized sci-fi game illustration with clean silhouettes, broad tonal blocks, subtle gradient and restrained outlines. Explicitly NOT photography, cinematic realism, NASA art, tiny miniature buildings, icons, or a planet filling the panel. Visual style of a friendly industrial spaceship game: ivory rounded armor, navy structural ribs, tiny cyan energy seams and small amber signal lights; subdued deep teal space background, restrained effects. Same image compares before/after construction.

## 固态行星

续句：

> SOLID ROCKY PLANET: ocean blue and sandy green continents. Right panel establishes a coastal refinery sunk into stepped bedrock with a short physical conveyor, a workshop with a big visible gantry and anchored pads on another landmass, a single compact orbital station, and an independent outer service shipyard clearly away from planet. Show a visible transport chain between these, landing shadows, no disconnected stickers. The ensemble's architectural footprint is as visually important as the planet.

原图：[solid-concept-a.png](images/solid-concept-a.png) · SHA-256 `27fc839e6385d0cad8185be637e284758a40d533b4f69ac83536c5beb27ebbac`

## 气态行星

续句：

> GAS GIANT: slate blue, muted jade and warm ivory cloud bands, no solid ground, faint upper atmosphere. Right panel has a broad floating pressure-resistant collection ring supported by aerostat pylons and tethers in upper cloud tops, a high orbital processing node receiving gas along a visible insulated transfer line, a separate workshop on the outer ring and independent shipyard further out. Buildings must NOT sit on a solid surface. Favor elegant concentric arcs and vertical depth, with each major function legible at game scale. The ensemble's architecture is as important as the planet.

原图：[gas-concept-a.png](images/gas-concept-a.png) · SHA-256 `d3da972813cd372b613f5b683246e62eb679a979bd516033cd50e8a226330791`

## 恒星

续句：

> MAIN-SEQUENCE STAR: warm gold luminous plasma globe with a darker mottled photosphere, slim restrained corona. Right panel has four equatorial magnetic-collector arcs held outside the star, a hovering shielded processing hub, a service workshop mounted on a cool outer truss, orbital station and independent far shipyard. Physical hot-to-cold radial zones and protected transport lanes are clearly designed as one system. No structure touches the photosphere. Luminous body and engineered corona array occupy balanced space, no magical energy beams.

原图：[star-concept-a.png](images/star-concept-a.png) · SHA-256 `5e8bc956a5b75f54e68884d9d1626955ba54c3a042d7f19d8273db21bd8dfc30`

## 红巨星

续句：

> RED GIANT STAR: huge but visually soft rust-red and muted coral photosphere with a sparse, translucent outer envelope and wispy prominence loops, recognizably old swollen star, distinct from the yellow main-sequence star. Right panel creates a very wide asymmetric standoff crescent of protected facilities OUTSIDE the diffuse envelope, with only slim remote collector probes reaching toward selected prominences; a shielded refinery/processing node on the crescent, workshop in a cool service spine, a small independent orbital station and shipyard on a remote counterweight pier. Clearly show long-distance transport along the crescent and open gap to stellar surface. Do not put a tight ring around the star, do not mount buildings on plasma. Make negative space and standoff distance the main design idea.

原图：[red-giant-concept-a.png](images/red-giant-concept-a.png) · SHA-256 `4cf3e724e466a5b244e8d0a6582758f6ce58039c00f107da35cc79a36fc1313d`

## 白矮星

续句：

> WHITE DWARF: an unusually SMALL, intensely bright blue-white stellar core with subtle compact halo, deep navy background and no giant sun-sized globe. Right panel keeps the core small and designs an asymmetric layered radiation-shield array around it: three large ivory/navy protective petal baffles offset from the core, a compact energy processing bay behind shields, workshop in their cool shadow, a single inspection station on an outer elliptical path and a separate drydock farther away. Visible sheltered transport corridor from inner shielded bay to outer dock. Architecture frames and protects from tiny dense star; no generic symmetric full ring and no buildings touching core. High contrast, but low bloom so structure remains readable.

原图：[white-dwarf-concept-a.png](images/white-dwarf-concept-a.png) · SHA-256 `e8f48c3bb2c80200669154ed29bfde69bfd855c164fafbe195795e38dff8bb76`

## 脉冲星

续句：

> PULSAR: a compact violet-blue neutron star with two narrow opposite polar beams and a thin tilted magnetic torus, unmistakably NOT a gas giant or ordinary blue star. Left bare state already shows the two beams and magnetic geometry. Right panel builds two protected service arcs in safe equatorial sectors away from polar beams, offset shielded signal/processing node, workshop mounted under one arc, compact orbital station on the other and independent shipyard in a remote beam-free sector. Show a clear transport route along the safe arc with small timed shutter elements, while leave both polar beam corridors visibly EMPTY. No structures intersect the beam cones; avoid a generic full ring, giant sphere or magical glowing clutter.

原图：[pulsar-concept-a.png](images/pulsar-concept-a.png) · SHA-256 `2566be40656a757dfee96907dcc00ba58248478385b635cf7fa579196bf1028d`

## 取舍

固态行星另有一张未归档的探索图，画面天体过大且偏写实，弱化设施整体关系；本目录仅固定上述六张候选。图像整体仍偏精细、尚未验证缩至现有模块后的设施识别，也未检验 UI 如何融入。用户可直接在同机位两态上判断结构方向，再决定是否调风格和占比。
