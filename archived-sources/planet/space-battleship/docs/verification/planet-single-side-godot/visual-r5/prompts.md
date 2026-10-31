# R5 imagegen 来源与提示词

所有九张候选图由 `image_gen.imagegen` 直接生成/编辑，`transparent_background:false`；原始输出复制归档，未用 Python、SVG、HTML 或后处理重绘。四张单体稿每次均给两张参考：① `assets/ships/fleet_20261019/player/01-frigate.png`，② `docs/verification/planet-single-side-godot/visual-r3/evidence/final-01-default-planet1.png`。这是风格/比例参照，**不是**让生成器复制战舰。正式战列舰另作人工目视对照，没有作为 imagegen 输入。单体稿分别使用下列“设施前缀 + 公共尾段”的原始拼接提示词。

## 单体稿公共尾段（四次均相同）

```text
Use the attached official cream-and-navy illustrated spaceship as the STYLE REFERENCE, and the attached 1440x900 planet screen as the SCALE/PALETTE REFERENCE. Create a NEW standalone single-building design sheet, one three-quarter hero and two smaller orthographic silhouettes of the SAME building. Style: the same clean hand-painted sci-fi game aesthetic as the frigate: bold readable silhouette, large warm ivory armor panels, deep navy blue structural gaps, clear dark outline, a FEW cyan glows and small amber signal lights. Simplified broad color shapes, soft illustrative shading, limited facets, no photoreal PBR, no copper pipes, no dense panel lines, no tiny greebles, no gritty rust, no heavy industrial realism. IMPORTANT: the complete building must still read when reduced to around 90px wide in the actual planet view. Dark flat navy presentation ground, no typography, no UI, no planet, no watermark.
```

| 输出 | 前缀原文（后接上述公共尾段） |
|---|---|
| `designs/station.png` | `SPACE STATION: a single broad navy inhabited ring with four large cream armor quadrants, one short axial cream docking core with obvious round dark entrance, only TWO broad dark-blue solar wings. Ring rotation and hinged solar wings should be plausible. Asymmetric but compact silhouette. Floats on orbital path. ` |
| `designs/refinery.png` | `SURFACE RESOURCE REFINERY: one broad low cream processing dome with a central amber smelting window, TWO big navy ore intake hoppers and ONE wide conveyor shape; three chunky landing feet visibly follow a curved ground tangent. Movable conveyor and two broad cooling shutters. This is a compact resource processing facility, not a factory skyline. ` |
| `designs/workshop.png` | `SURFACE WORKSHOP design PROPOSAL: a low wide cream rectangular fabrication bay with ONE tall navy gantry arch, a single large articulated cyan-navy arm holding a simplified ship panel, one broad warm-lit opening. Two or three chunky masses; no sprawling factory complex. Movable gantry and arm. ` |
| `designs/shipyard.png` | `ORBITAL SHIPYARD design PROPOSAL: an ASYMMETRIC open docking berth with ONE chunky vertical cream/navy keel on the left and only TWO broad navy cantilever jaws reaching right, leaving the right side open; a single large sliding crane and one round cyan docking collar. No U-shaped outline, no parallel ladder rails, no fragile truss. This must look distinct from the orbital station at 100px and leave a clear empty berth for a scout craft. ` |

## 单设施整屏配合图

每次传两张参考：① 原 R3 实机完整截图（上文），② 本轮对应 `designs/*.png`。原始提示词为“公共前段 + 相应中段 + 公共尾段”拼接；下表保留全部实际文本，拼接处保留空格。

公共前段：

```text
Edit the FIRST referenced existing 1440x900 GAME SCREENSHOT into a full-screen SCALE FIT concept mockup. Preserve the exact whole-screen framing, top cream navigation and Chinese UI, original painted blue-green planet and cloud texture, starfield, right-side battle lane and cream navy ship. Keep wide landscape view, not a closeup.
```

| 输出 | 中段原文 |
|---|---|
| `fit/refinery.png` | `Replace ONLY the small resource refinery/factory attached to the planet's upper-left sunlit surface (currently a light-gray compact building near x320 y350) with the SECOND reference simplified cream dome, navy ore hoppers, amber furnace and chunky feet, at approximately the SAME original 80-100px screen size. It must follow the globe tangent and rotate with the surface conceptually; no giant industrial city. Preserve the orbital station, workshop and shipyard as they currently appear.` |
| `fit/workshop.png` | `Replace ONLY the small workshop attached to the planet's lower-left/front surface (currently subtle/partly obscured near x335 y633) with the SECOND reference simplified broad cream workshop and one navy gantry, at approximately 80-100px wide, tangent to the globe. The open warm work bay should remain legible at this scale, but no oversized building. Preserve the upper-left refinery, orbital station and shipyard.` |
| `fit/shipyard.png` | `Replace ONLY the thin ladder-like shipyard beside the planet's lower-right edge (currently near x660 y590) with the SECOND reference ASYMMETRIC single-keel open shipyard, about 100-120px wide at this full-screen scale. The navy cantilever berth and cyan round collar should still read; make it visually separate from the orbiting station above it. Preserve refinery, workshop and station.` |

公共尾段：

```text
 Match the established illustrated game style of the screenshot and the concept, not photorealism. No labels, comparison panels, extra buildings or new UI. This is a proposed imagegen concept composite, not an actual runtime capture.
```

`fit/station.png` 的独立原文（同样参考① R3 截图、② 本轮空间站稿）：

```text
Edit the FIRST referenced existing 1440x900 GAME SCREENSHOT into a full-screen SCALE FIT concept mockup, preserving the exact whole-screen layout, top cream navigation and Chinese UI, entire original painted blue-green planet, starfield, and right-side battle lane and ship. Keep the image in the same wide landscape 1440:900 framing, not a closeup. Change ONLY the small orbital space station that currently appears to the right of the planet's upper-right edge into a simplified version of the SECOND reference design (cream segmented ring, navy core, two blue solar wings). It must be small, around 105 pixels across on this full screen, with the same visual scale as the existing station; it is a game-view compatibility illustration, not a gigantic art hero object. Preserve the refinery, workshop and shipyard as they currently appear. Keep readable negative space and plausible orbital separation. No labels, comparison panels or extra buildings. This image is explicitly a proposed concept composite and not an actual game runtime capture.
```

## 四设施同屏概念图

参考依次为 ① R3 实机截图、② `designs/station.png`、③ `designs/refinery.png`、④ `designs/workshop.png`、⑤ `designs/shipyard.png`。提示词原文：

```text
Create ONE full-screen GAME-VIEW SCALE concept composite by editing the FIRST referenced actual 1440x900 planet game screenshot. Preserve the original wide layout, cream Chinese UI, exact painted blue-green planet texture and size, right battle lane and frigate, starfield and orbit lines. Replace only the four old cream/gray buildings with simplified designs from the four subsequent references: reference 2 ring station at the original small upper-right orbit position (about 100px wide), reference 3 ore refinery anchored at upper-left planet rim (about 85px), reference 4 wide workshop attached to lower-left/front planet surface (about 95px), and reference 5 asymmetric open shipyard at lower-right OUTSIDE the planet (about 110px). Keep each at comparable actual screen scale: tiny compared with the 460px diameter planet, no enlarged hero assets. They must share the same cream-and-navy illustrated spaceship language with bold outlines and few cyan lights; keep readable silhouette and clear separation of station trajectory and shipyard berth. Do not invent new buildings or change UI. The mockup is a proposed concept image, NOT a Godot runtime capture or proof of orbital clearance. No labels or watermark.
```

生成器固定输出 `1586×992`，与参考画面约同宽高比；此数据只用于整屏相对尺寸观察，不能替代 Godot 实际换模或运行采样。
