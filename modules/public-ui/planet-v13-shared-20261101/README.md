# v13星球当前公共宿主整页候选

运行源 `6bf0dd2dd025acd124c11bcffb60b830909e071e`，星球固定交接 `82526bc820b1b2fa009c0959bf150cb71b40339a`。四件facilities_v8模型与planet_facility_scene、planet_orbital_spine、planet_spine_opaque七件逐blob同源；panel与e7591438相同，ready人员撤回/引用清理/反馈修复保留，公共main/导航/主题/装备未覆盖。

## 查看

- `planet-overview.jpg`、`planet-facilities.jpg`：当前公共宿主完整1440×900页面。
- 13张原PNG及同尺寸小于1MiB JPEG，覆盖总览、四设施详情、人员、探索/征服展开与滚动、关闭、下拉及装备返回，均来自本版同一次运行。
- `planet-v13-shared-1x-6s.mp4`：1440×900、30fps、180帧、6秒；Godot MovieMaker固定步长离线生成，展示层1×待机运动，未插帧，不是实时性能录像。驱动、日志与源帧区间见driver.gd/run.log/movie-segment.json。
- `video-parts.json`列出小于768KiB分片顺序和完整/分片SHA256，按顺序拼接`video-parts/part-*.bin`即可还原。motion-review覆盖180帧，motion-keyframes保留7张原尺寸关键帧。
- `author-review.md`给出明确结论：本轮星球整页具备完整用户评价条件；制造舱暗板分段、空间站翼端/环后缘分离为具体剩余制作项。不是终验或合main。

受控状态为星球1、探索240、征服、四设施已建。作者已亲看整页与帧序列，导入及运行未报脚本/资源/着色器错误；原组旧宿主图和旧动态没有当成本包当前证据。共同规范67d1b4ce继续有效，当前不自行向用户发送或合main。
