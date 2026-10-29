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

## 取舍

固态行星另有一张未归档的探索图，画面天体过大且偏写实，弱化设施整体关系；本目录仅固定上述首批候选。三张已固定图仍偏精细、尚未验证缩至现有模块后的设施识别，也未检验 UI 如何融入。用户可直接在同机位两态上判断结构方向，再决定是否调风格和占比。
