# 武器弹体素材

2026-09-14 用户要求：三种攻击武器图像应更有区分度并贴合名称。使用内置 image_gen 生成，原始透明 PNG 原样复制入项目；未修改玩法或数值。消费端：scripts/main.gd 的 PROJECTILE_TEXTURES / PROJECTILE_SIZES。

- laser-pulse.png：青白细长脉冲光束。
- cannon-slug.png：铜箍金属弹丸、橙色曳光。
- guided-missile.png：白色弹身、红色弹头、尾翼、蓝紫推进焰。

## 最终生成提示词

显示尺寸由 main.gd 的 PROJECTILE_SIZES（各武器基准尺寸）与 PROJECTILE_SCALE（统一缩放，当前0.65）共同控制。新增武器素材时补充对应纹理和基准尺寸，即可沿用统一缩放；原始PNG保留，便于后续调整。

### laser

Use case: stylized-concept. Asset type: transparent 2D side-scrolling sci-fi game projectile sprite. Single cyan pulse laser bolt pointing exactly right, centered horizontally. Long extremely slender white-hot cyan beam core, sharply tapered right tip, clean turquoise outer glow and faint linear energy streak tail to left. No solid metal, no fins, no rocket. Crisp graphic game art readable at 80x18 pixels against near-black navy space. Occupy 85% width and 25% height of a wide landscape canvas, fully transparent background with real alpha, no checkerboard, no text, no border, no other objects.

### cannon

Use case: stylized-concept. Asset type: single transparent 2D sci-fi side scrolling game projectile sprite. A magnetic railgun cannon shell flying exactly right, strict flat side view: short chunky pointed tungsten steel slug with bright brass copper driving bands, incandescent amber tip, small orange sparks and short amber motion streaks trailing left. Clearly a solid heavy bullet, NOT a rocket, NO fins, no long laser. Crisp graphic illustration with simple readable silhouette at 34x18 pixels on dark navy space. Wide landscape canvas, centered, object occupies 70% width, 30% height. Real transparent alpha background, no backdrop, no checkerboard, no text, no frame, single projectile only.

### missile

Use case: stylized-concept. Asset type: transparent 2D side-scrolling sci-fi game projectile sprite. Single guided missile flying exactly RIGHT, strict flat side view. Ivory white long slim armored fuselage, red pointed nose cone on right, two prominent triangular swept tail fins at left rear, dark small guidance panels, bright violet blue rocket exhaust trailing LEFT. Readable rocket silhouette, clearly different from a thick brass cannon bullet or cyan laser beam. Crisp graphic game illustration simplified for display at 64x24 pixels. Wide landscape canvas, centered, occupies 85% width and 35% height. Real transparent alpha background, no black backdrop, no checkerboard, no typography, no border, no other objects.
