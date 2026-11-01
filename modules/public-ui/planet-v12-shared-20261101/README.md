# v12星球公共宿主整页候选

运行源 `ee5377bf2a4576802245d0572b31163fe91ca657`，星球固定交接 `85db1e02b7f14237ca202065299d988a9658c594`。精确更新四件facilities_v8模型及planet_orbital_spine脚本，五件逐blob同源，公共宿主/导航/主题/面板/装备保持。业务准备为受控星球1四设施已建。

## 查看

- `planet-overview.jpg`、`planet-facilities.jpg`：总览与设施面板，当前公共宿主1440×900。
- 共13张完整PNG及同尺寸小于1MiB JPEG，四设施详情、人员、征服详情滚动、关闭及装备返回一并保留；同源码的普通驱动与movie驱动两次取图，余额/相位可不同。
- `planet-v12-shared-1x-6s.mp4`：1440×900、30fps、180帧、6秒。Godot MovieMaker固定30fps离线渲染，展示层速度1×；截取固定设施快照后的连续180帧，无插帧，不是实时帧率/性能录像。源帧区间与实际墙钟见movie-segment.json。
- 大文件读取受限时，按`video-parts.json`顺序拼接`video-parts/part-*.bin`，各件640KiB以下；清单带每件及完整视频SHA256。6张motion-review覆盖180帧，motion-keyframes为7张原尺寸关键帧。
- 具体整页视觉结论见`author-review.md`：可评阶段方向及组织，材质/轮廓仍未完成。

原组旧v10动态没有充当本版证据。当前导入、普通运行和最终movie退出日志未见脚本/资源错误，VSync为软件驱动既有提示。录制前移除三个同UID、精确旧有限驱动路径的残留进程，记录只属环境清理；本包不作性能改善结论。当前不合main，最终完整稿再交用户。
