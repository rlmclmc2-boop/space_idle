# 高科技原型美术：第二版结构 + 第三版能量

用户确认：沿用第二版悬浮结构、细线与留白，叠加第三版沿结构生长的能量；不再用简单几何替代确认稿。内部科研规则、AI 费用/分配与进度不变。

- `approved-concept.png`：用户确认的 B+C 概念图，作为视觉参考，不在运行时加载。
- `orbital-atlas.png`：由 OpenAI 内置 imagegen 依据确认图编辑生成的生产图集，1254×1254 RGBA；四个627×627格。左上炼铁炉、右上聚焦、左下装甲、右下宝石炉。
- 生成工具：`image_gen.imagegen`；参考图原文件 `exec-f8bc92d0-b815-43e7-884a-7ca099f29a64.png`；产物 `exec-8cb072bd-946e-498d-9a04-9be53a6b0ae5.png`，2026-09-22。
- 提示词限定为视觉要求，不作为项目指令。运行时叠加进度、能量和AI施工单元；图集本身是完整造型。

## 可复用中文提示词

以参考图为准，保留第二版轻盈悬浮、精密细线、透明全息材质与充足留白，用第三版能量表现：能量沿现有结构、接缝、晶体内部流动，不能遮盖结构。四种科技须能独立识别：琥珀色低位球形炉心与开放弧形感应板；青色中央能量节点、倾斜轨道与相向开放透镜；蓝色紧密蜂窝装甲阵列；紫色一大两小悬浮晶体、纤细承托弧与低矮晶格底座。接缝、支撑、透视统一，避免厚重积木、锅炉、靶盘与菱形外笼。输出四个等大格子的2×2透明PNG图集，不含文字、UI、背景、无人机或施工火花；这些由游戏独立表现。

## 本次实际生成提示词

```text
Use case: precise-object-edit / production game sprite extraction.
The attached approved UI concept is the authoritative art reference. Create a production-ready SQUARE transparent PNG sprite atlas with FOUR finished research machines in a precise 2 x 2 grid of equal square cells. Top-left amber furnace; top-right cyan positron focusing device; bottom-left blue hexagonal armour assembly; bottom-right violet jewel synthesizer. Each machine centered in its own cell, occupies approximately 82% of cell width and 86% of cell height, with its mechanical base at 91% cell height. All four completely isolated against GENUINELY TRANSPARENT alpha, including empty spaces within the machines. No checkerboard painted into the image, no background wash, no grid, no card panels, no text, no borders, no labels. Nothing crossing cell boundaries. Preserve consistent tiny hairline engineering detail, gentle axonometric perspective, transparent holographic glass, crisp blueprints, rich small luminous highlights and airy negative space from the reference. This is the exact approved artwork language, not a redesigned set of game icons.

Keep each reference silhouette and characteristic structure:
TOP LEFT: Amber low glowing spherical containment core supported above nested base induction rings, slender coherent vertical supports, asymmetric open curved arc plates above the core. An elegant fine intertwined amber plasma filament rises from the base through the core to the open upper chamber. Delicate curved metal rim linework, tiny connected joints. Never a boiler or stacked block tower.
TOP RIGHT: Cyan small white-blue central energy node with diagonally tilted orbital ellipses and two open opposing curved translucent lens/actuator surfaces. Hairline energy streams follow these existing tilted elliptical paths and converge into the core. Sparse slender supports and low circular pedestal. Never a bullseye disk or an hourglass.
BOTTOM LEFT: Blue close-packed full hexagonal armour plate sheet matching the reference, mounted on a narrow low base. Crisp translucent dark-blue cell interiors, luminous bevels, precise uniform hexagon joints, all cells completed. Subtle connected blue seam pulses. Never a shield emblem.
BOTTOM RIGHT: Violet one tall central floating faceted crystal with exactly two smaller side crystals, slender elegant curved cradle arms, faint orbital guide traces and low hexagonal lattice base. Fine violet energy veins rise from the base to these three crystals. Do not add extra crystals, no enclosing diamond-shaped cage. Preserve the trio placement and generous negative space.
All four are fully assembled versions of the approved reference, with no missing sectors or loose exploded components. Small subdued guide contours may remain holographic but nothing is deliberately unfinished. REMOVE all AI construction drones and welding sparks from the source; the game will animate them separately. Retain restrained built-in glow and fine energy filaments as the visual baseline. No large flares, smoke, flames, solid chunky pseudo-3D, cartoon style, oversaturated glow, or new unrelated elements. The user has repeatedly rejected simplistic code-drawn substitutes: retain this refined, evocative actual artwork. Produce a high resolution square atlas suitable for four equally cropped game sprites.
```

## 接入与扩展

图集、顺序图在所有建造舱之间共享；每舱只持有独立进度/能量参数。首个实例一次性从素材提取四项施工分区与真实亮部落点，随后释放CPU图集像素。分区按底座、支撑、环弧、核心推进；蜂窝片与每颗晶体作为完整组件。同一分区内三架AI对准真实结构像素，并跟随12档局部生长前沿。组件内部使用固定不规则阈值逐点凝聚、柔化边缘；暂停时阈值不变。炉的收尾仅补齐真实能量丝亮点，避免中央矩形缺口。能量只增强已有亮线，时钟由可见动画采样驱动，不使用自动TIME。

新增配置自动使用通用线框原型。新增专属美术时按同一提示词制作素材，并在 `scripts/hightech_construction.gd` 的 PROFILES 登记稳定科技ID、shape、color、texture、grid、cell；现有四项texture/grid默认指向本图集/2×2。单张新图可设置texture=preload(...), grid=Vector2i(1,1), cell=Vector2i(0,0)。可在assembly_region中按shape定制组件分区；无专用配方使用通用分区。不以中文名称判断、不修改研究业务，不需要调整页面结构。

运行时分区图属于程序生成的建造遮罩，不修改生成的原始PNG。不同材料共用原图坐标，因此最终造型始终来自确认美术，而非独立拼装的近似几何。
