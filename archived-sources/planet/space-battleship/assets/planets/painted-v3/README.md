# 星球第三版球面贴图

依据已批准 `e78af05f` 的球面层次重新制作，替换实机中被否定的粗描边矢量大陆。`surface.png` 为无球形光照的平面经纬地表颜色贴图，`cloud-density.png` 为独立灰度云密度；两者通过既有相位投影持续运动，光向由 shader 固定。采用柔和昼夜过渡、云密度/邻域阴影及边缘大气，取消旧黑色轮廓。

两张 PNG 由内置 `image_gen.imagegen` 生成，提示词和 Git 来源见 [imagegen-requests.json](imagegen-requests.json)。原始文件直接复制，未额外压缩、缩放、裁切或拼接；Godot `.import` 生成 mipmaps 用于运行采样，不改变原图。建筑参考同批生成，归档于 `art_sources/planet_facilities_v3/imagegen-reference.png`。

本组只替换原始默认球的外观资源，已配置的其他星体贴图/轴比/脉动仍由其原有表现定义提供，不修改 Excel 或玩法。
