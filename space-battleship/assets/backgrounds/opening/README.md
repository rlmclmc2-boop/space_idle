# 开场背景贴图

`stage_01.png`与`stage_02.png`为同一画面的连续裁片，各572×1199像素，共享960行可见内容，两端保留2像素滤波余量。

导入使用无损压缩、无mipmap、无尺寸上限；采样为线性过滤、禁用repeat、source color。素材覆盖前两段，其他段使用当前消费者提供的背景。

制作要求见[M1](../../../docs/game-design/art/modules/battle.md)，当前消费来源见[资产来源](../../../docs/game-design/art/sources.md#s3)。
