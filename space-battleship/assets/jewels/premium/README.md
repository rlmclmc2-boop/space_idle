# 宝石中心美术资源

`crystal-atlas.png` 为内置 image_gen 生成的单张透明图集，1983×793 RGBA，按5列×2行采样。程序通过 AtlasTexture 直接取区域，未拆图、重绘或修改生成图像。原配置中 `res://assets/jewels/<id>.svg` 的默认映射由新图集接管；其他自定义 `jewel.image` 路径仍优先。未修改正式配置投影。

| 从左到右 | 第一行 | 第二行 |
|---|---|---|
| 1 | ID 1 熟练：青色风筝切形 | ID 6 连发：橙色双晶 |
| 2 | ID 2 适应：蓝色椭圆切形 | ID 7 暴击：红色钻石切形 |
| 3 | ID 3 吸铁：琥珀色六角 | ID 8 蓄能：金色棱柱 |
| 4 | ID 4 电子战：紫色晶簇 | ID 9 抗性：冰蓝八角 |
| 5 | ID 5 维修：绿色水滴 | ID 10 坚韧：薄荷绿方形 |

`workshop-frame.svg` 与 `toggle-on/off.svg` 为代码原生UI矢量装饰，只负责静态背景与开关外观。根面板不逐帧重绘。

## 生成方式与最终提示词

使用内置 image_gen；没有使用API/CLI回退。生成原件保留在 Codex generated_images；项目消费本目录副本。

```text
Use case: stylized-concept. Asset type: ONE production sprite atlas texture for a science-fiction game's gemstone inventory, consumed directly as a single 5-column x 2-row texture atlas. Generate a 2560x1024 image with a genuinely transparent RGBA background. EXACTLY ten isolated premium crystalline gemstone sprites on an invisible regular grid: each cell is 512x512, centered precisely. Row one centers x=256,768,1280,1792,2304 and y=256. Row two same x positions and y=768. Each jewel occupies about 310x340 pixels, with generous completely transparent padding around it; absolutely no sprite touches an adjacent cell. Consistent three-quarter near-front camera and top-left studio lighting. High-end hand-painted 3D game inventory art: sharp jewel facets, convincing translucent colored glass, deep internal refraction, crisp small white specular highlights, subtle internal glowing energy veins. Simple readable silhouettes, rich saturated colors against transparency, restrained bloom tightly contained to the gemstone. NO square tile backgrounds, NO pedestals, NO frames, NO text, NO numbers, NO icons painted over gems, NO UI, NO checkerboard baked into pixels, no loose particles. Row 1 left to right: (1) cyan elongated kite-cut crystal with three angular crown facets, (2) sapphire blue rounded oval-cut gem, (3) warm amber compact hexagonal-cut crystal, (4) amethyst violet three-point crystal cluster fused at base, (5) emerald green pear-cut gem. Row 2 left to right: (6) fiery orange matched twin crystals joined diagonally into one compact silhouette, (7) ruby crimson classic brilliant-cut diamond silhouette wide crown pointed bottom, (8) luminous gold upright long prismatic crystal with oblique top, (9) icy pale blue broad octagonal shield-cut gem, (10) vivid mint-jade square cushion-cut gem. Equal apparent size and optical weight. Polished collectible items for a sophisticated navy and charcoal sci-fi interface, not cartoon clip art, not flat vectors. This is a single precisely aligned atlas asset, no surrounding presentation.
```
