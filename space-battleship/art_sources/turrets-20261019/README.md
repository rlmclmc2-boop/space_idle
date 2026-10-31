# 炮塔静态源制作

`prepare_assets.py` splits the four solid alpha components, retains their two-pixel anti-aliased fringe, removes isolated low-alpha noise, and pads each PNG by 16 pixels. Hull/weapon interiors are copied directly. The output manifest records bounds, source base centres, padded image anchors, visual pixels-per-model and hashes. The bolt's visible glow is cropped and reduced offline; both presentation paths draw the same vertical PNG at 14 × 34 internal screen pixels.


当前轴心、完整发射口及双导弹口以assets/weapons/fleet_20261019/manifest.json与ship_geometry_convention.gd共同定义。旧“原模型Muzzle独立作为真实发射权威”的描述已不适用；不要从本源图尺寸改战斗数值。
