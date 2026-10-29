# 装备当前入口：main功能认可，美术继续修正

用户认为main功能没问题、质感未达标。main功能基线 `e3b38d7b6d8256f6031e1b086c7db7812b6a441f` 保持；原美术 `ba7afb24/c6e54749` 已被根实图与原Astra退回，不再作为品质候选通过依据。

**当前源码 `f1a16bf6b59aab2005da89ff3062f316e807849a`：** 同一分支art/equipment-materials-main-20261029，修正跨比例纹理、读数/报价亮贴片和动作层级。单循环数量/独立购买及当前操作组/Owner语义保持。新素材按实际屏幕像素平铺，公共顶栏恢复main兼容，具体边界与同版4整屏/4原像素局部见[当前像素尺度材质候选](materials-pixel-scale/README.md)。待原Astra/根实图审查，不自判达标，不pushmain。

历史[前一美术退回候选及其循环逻辑证据](materials-main-revision/README.md)、[原9ed排版/删记录/等级刷新入口](https://github.com/rlmclmc2-boop/space_idle/blob/9ed2090dcee8fb1d90d61846e92e6b1f94622332/space-battleship/docs/verification/equipment-hangar-godot/workbench-optical-revision/README.md)、[main最小接入证据](../main-integration/README.md)保留真实版本；旧视频/旧图不能替代本次材质判断。
