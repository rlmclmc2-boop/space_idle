# 连续船坞背景

文件：`hall-background-v2.png`，1536×1024，2026-09-26。
使用内置 `image_gen.imagegen`，按 imagegen skill 制作；未使用 CLI。
用途：`scripts/hightech_hall.gd` 作为共享背景加载；建筑、研究特效、文字和按钮均由游戏独立绘制。资产不包含 UI 或建筑；替换旧程序网格、重复吊架和平台装饰，不改变业务配置。

## 实际提示词

```text
Use case: stylized-concept. Asset type: production game background texture for a high technology orbital construction hall, not a UI mockup. Create a single continuous empty hangar interior matching a dark blue realistic high-tech strategy game reference: industrial metallic floor, restrained cyan floor lighting, mechanical gantry ribs only near outer left/right walls, distant observation window with space and a small planet near the upper edge. Landscape 3:2 composition. Camera elevated frontal, coherent perspective. The background will sit UNDER four large holographic buildings in TWO COLUMNS and TWO ROWS; leave broad quiet open floor regions around normalized centers (0.25,0.33),(0.75,0.33),(0.25,0.81),(0.75,0.81). No buildings, no holograms, no circular platforms, no circular rings in this background: platforms and buildings are separate interactive game layers. Prioritize continuous shared floor and realistic material depth over decorative clutter. Dark navy steel with subtle blue rim light and sparse tiny warm practical lights. The brightest regions should be small peripheral lights; keep the central floor moderately dark for transparent cyan/amber/purple buildings. No text, no numbers, no labels, no HUD, no buttons, no card boundaries, no grid overlay, no people, no ships in foreground, no additional objects. Production rendered realistic environment, crisp fine machinery materials, understated lighting, controlled detail, no heavy fog.
```
