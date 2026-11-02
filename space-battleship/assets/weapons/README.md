# 武器弹体素材

三种飞行弹体使用内置image_gen生成，保留原始透明PNG。当前入口为 `src/main.gd`，通过 `SpaceCombatPresentation` 接入保留的原生/GPU 武器表现。

- laser-pulse.png：青白细长脉冲光束。
- cannon-slug.png：铜箍金属弹丸、橙色曳光。
- guided-missile.png：白色弹身、红色弹头、尾翼、蓝紫推进焰。

## 运行时纹理预算

三张飞行弹体PNG保留原始分辨率，导入尺寸限制由各自.import维护；显示尺寸由当前战斗呈现消费者决定。

## 槽位武器图标

`icons/` 保存装入舰船圆形槽位的侧视内嵌武器模块图标；根目录三张 PNG 仍只负责战斗中的飞行弹体，不互相替换。图标不再重复绘制槽位外环，透明边距用于露出舰船原有安装座；三张图标均为方形透明源图，按美术规范的槽位尺寸缩放：

- `icons/laser-emitter.png`：深色短发射器、青白侧向发射口与上下青色能量轨。
- `icons/missile-pod.png`：白色装甲双发射舱、红色中脊与紫蓝状态光。
- `icons/cannon-turret.png`：深色短炮管、铜箍与琥珀色磁能线圈。

图标不含外层槽位环、舰体、背景、文字或飞行弹体；详细槽位适配约束见 [M2](../../docs/game-design/art/modules/equipment.md)。

## 最终生成提示词

原始PNG与生成提示词用于素材重建；显示与挂点要求见[M1](../../docs/game-design/art/modules/battle.md)及对应资产manifest。

### laser

Use case: stylized-concept. Asset type: transparent 2D side-scrolling sci-fi game projectile sprite. Single cyan pulse laser bolt pointing exactly right, centered horizontally. Long extremely slender white-hot cyan beam core, sharply tapered right tip, clean turquoise outer glow and faint linear energy streak tail to left. No solid metal, no fins, no rocket. Crisp graphic game art readable at 80x18 pixels against near-black navy space. Occupy 85% width and 25% height of a wide landscape canvas, fully transparent background with real alpha, no checkerboard, no text, no border, no other objects.

### cannon

Use case: stylized-concept. Asset type: single transparent 2D sci-fi side scrolling game projectile sprite. A magnetic railgun cannon shell flying exactly right, strict flat side view: short chunky pointed tungsten steel slug with bright brass copper driving bands, incandescent amber tip, small orange sparks and short amber motion streaks trailing left. Clearly a solid heavy bullet, NOT a rocket, NO fins, no long laser. Crisp graphic illustration with simple readable silhouette at 34x18 pixels on dark navy space. Wide landscape canvas, centered, object occupies 70% width, 30% height. Real transparent alpha background, no backdrop, no checkerboard, no text, no frame, single projectile only.

### missile

Use case: stylized-concept. Asset type: transparent 2D side-scrolling sci-fi game projectile sprite. Single guided missile flying exactly RIGHT, strict flat side view. Ivory white long slim armored fuselage, red pointed nose cone on right, two prominent triangular swept tail fins at left rear, dark small guidance panels, bright violet blue rocket exhaust trailing LEFT. Readable rocket silhouette, clearly different from a thick brass cannon bullet or cyan laser beam. Crisp graphic game illustration simplified for display at 64x24 pixels. Wide landscape canvas, centered, occupies 85% width and 35% height. Real transparent alpha background, no black backdrop, no checkerboard, no typography, no border, no other objects.
