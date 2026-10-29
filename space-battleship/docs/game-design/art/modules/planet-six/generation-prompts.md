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

## 独立建造分步图：固态行星首套

这三张由 `image_gen.imagegen` 编辑同一[固态原图](images/solid-concept-a.png)，输入 `referenced_image_paths=[该图的 Git 路径]`，`transparent_background=false`。每次实际提示词为以下共同前缀直接接相应续句（前缀末尾已有空格）。图像模型会微调地貌细节，不能声称逐像素锁定同一球面。

共同前缀：

> Edit the attached TWO-PANEL solid rocky planet concept art. Preserve both panels, exact camera, planet size, ocean/coastline/land pattern, lighting, background and framing. The LEFT panel remains fully bare. In the RIGHT panel show a credible standalone construction stage, with only the explicitly named built facilities; remove every other facility and its lights, transport craft, foundations, rails, docks, conduits and shadows entirely, restoring the underlying land/ocean or empty space. Do not show ghost outlines, future pads or placeholders. Keep same painterly ivory/navy/cyan style, no labels, text or UI. Each built facility must have its own necessary support and be complete in this stage.

| 步 | 原提示词续句 | 原图 SHA-256 |
|---|---|---|
| [01 空间站](stages/solid/01-station.png) | STAGE 1: ONLY the compact orbital station at top is built. Its own small closed orbital hub and self-contained docking nipple are visible; there are NO surface buildings, no outer drydock, no cargo route to the surface, no construction markers. | `eee958e9988f5a445de1b5ae5ed4c0b3e255f058613623fc291e226f5202cbe4` |
| [02 精炼厂](stages/solid/02-refinery.png) | STAGE 2: the compact orbital station AND the coastal refinery at lower-left land are built. The refinery includes only its own bedrock foundation, inlet and short local feed conveyor. No workshop, no gantry bay, no outer shipyard, no long transit bridge that depends on future buildings. | `9dd6bf6924ef59d54963f6649e3ddd3306a2c0c89d6163dd6087af93f1faa512` |
| [03 工坊](stages/solid/03-workshop.png) | STAGE 3: the compact orbital station, the coastal refinery, AND the land-anchored equipment workshop with clear gantry work bay at upper-right land are built. Each land facility has its own complete foundation; a short service route can connect the two built land facilities. No outer shipyard, drydock, cranes or rails to a future dock. | `89eb39e821e37bed013f5d33e98f8989d1d5d2658dd38242805c7d74a74440dc` |

阶段 0 与 4 取既有完整概念图的左右两态；下次继续其余五类的三个中间阶段。所有图均为静态概念编辑，非实际独立施工或自转的运行证据。

## 独立建造分步图：气态行星

阶段 01、02 以[气态原图](images/gas-concept-a.png)为 `referenced_image_paths`，共同前缀及续句如下；阶段 03 首次输出把站体黏到云顶，未归档，改以[阶段 02](stages/gas/02-refinery.png)作参照重生，确保空间站独立。

共同前缀：

> Edit the attached TWO-PANEL gas giant concept image into a staged construction view. Preserve the same gas planet cloud pattern, camera, scale, lighting and framing in both panels. LEFT panel remains the bare gas giant. RIGHT panel includes ONLY the facilities named for this stage. Remove all unbuilt structures, future ring segments, pylons, tethers, docks, paths, craft and their shadows completely. The gas giant has no hard ground. Every visible structure must have its own aerostat or orbital support and be complete without a later building. No text/UI.

| 步 | 实际续句／独立提示词 | 原图 SHA-256 |
|---|---|---|
| [01 空间站](stages/gas/01-station.png) | STAGE 1: ONLY the compact orbital station high above the gas giant exists, with its own short docking arms. No atmospheric platform, no pressure ring, no processing node, no workshop, no outer shipyard. | `310918e751ffd780cfa03572ca764cf088e0bf114790dfbe05cfad7f284d6ce9` |
| [02 精炼厂](stages/gas/02-refinery.png) | STAGE 2: orbital station plus ONE independent refinery/collection platform in upper atmosphere. The platform brings its own pair of aerostats, short pressure intake and tiny processing deck, and sends cargo via small free-flying shuttles to station. No wider ring, no workshop, no shipyard or connections to unbuilt structures. | `c3dbf579b7fbd87840aee0178679b7519bd7ce304380216190754b932d1dfe2f` |

阶段 03 独立完整提示词：

> Edit this attached TWO-PANEL gas giant STAGE 2 image by ADDING EXACTLY ONE new workshop to the RIGHT panel. Keep BOTH panels' planet, storm, station and existing two-balloon refinery collector at the right side in the EXACT same positions and scale. In empty space just LEFT of the existing refinery collector, add a distinct small ivory/navy WORKSHOP with a visible blue gantry bay on its own pair of aerostat balloons and local tethers, separated from the refinery. A short bridge may connect those two built floating platforms; the upper station remains freely orbiting with empty space below it, not attached to the cloud or workshop. Do not add the outer shipyard, drydock, future ring segments, giant structure, extra station, text or UI. Show only station + refinery + workshop, each complete and self-supported. Maintain painting and camera.

[03 工坊原图](stages/gas/03-workshop.png) SHA-256 `e6073da17d7d15331258028f51f93ce84824957bdee462b932cd4eec2176992c`。气态阶段 0／4 仍取既有完整概念图两侧；分步图只是静态设计，不是运行证据。

## 独立建造分步图：恒星

01、02 以[恒星原图](images/star-concept-a.png)为图像编辑输入；03 以[阶段 02](stages/star/02-refinery.png)为输入，防止编辑时丢失已建站体。以下共同前缀直接接 01／02 对应续句。

共同前缀：

> Edit the attached TWO-PANEL yellow main-sequence star concept into a construction stage. Keep the same star, camera, size, glow, background, and left bare panel. On the RIGHT retain only facilities explicitly built in this stage; erase every unbuilt arc, truss, drydock, platform, path, craft and shadow, restoring empty space and corona. No buildings touch the photosphere. Each built facility has its own shield and support, no future structures or placeholders. Maintain ivory/navy/cyan painterly game style, no text or UI.

| 步 | 实际提示词续句 | 原图 SHA-256 |
|---|---|---|
| [01 空间站](stages/star/01-station.png) | STAGE 1: ONLY one small self-contained orbital space station above the star with its own short protected docking arms. No magnetic collector arcs, no refinery node, no workshop, no shipyard. | `600974a29eafbd02846c7127661cf57b7bf15f5f923f2fcfcae66d7af5b82104` |
| [02 精炼厂](stages/star/02-refinery.png) | STAGE 2: orbital station plus ONE shielded refinery: a single short magnetic collector crescent outside the star on the left, with its own support hub and shielded processing pod. Transfer to station by free-flying shuttle. No remaining ring arcs, workshop, cold truss, outer shipyard or dock. | `c70579477b1b55d8b753545b10bf7e9e6acf7318e2d77bc5d9d1a8b698bfe4bd` |

03 独立完整提示词：

> Edit this attached two-panel STAGE 2 stellar construction image. LEFT panel remains bare star. RIGHT panel MUST KEEP the large orbital station above the star EXACTLY as seen, and KEEP the one short shielded magnetic refinery crescent to the star's left EXACTLY as seen. Add exactly one new, small workshop with a recognizable gantry work bay BELOW AND OUTSIDE the refinery crescent, mounted on its OWN compact cool-side truss platform. A short shuttle path may run between built nodes. DO NOT remove, shrink, relocate, or replace the orbital station; do not add shipyard, drydock, future magnetic arcs, large full ring, text or UI. Camera, star scale, space background and painting stay the same.

[03 工坊原图](stages/star/03-workshop.png) SHA-256 `2037b41e3422a252ae1ea7fbb59b3fbadb556b4f4810dd3203750f8aa54b3ecd`。首次由完整态直接编辑的 03 丢失站体，未归档；本图以 02 为输入重生。恒星阶段 0／4 仍取原图左右两侧，图像不构成自转或独立施工的运行验证。
