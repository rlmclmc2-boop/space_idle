# Cannon redesign — same task, value hierarchy09
目标：解决08顶面近黑缩小看不清，中亮钢灰炮机顶面+更亮白侧甲+少量暗侧/缝/炮口。
基准/分支：63f75835，art/cannon-redesign-20261020。
范围：仅明度层级，不恢复细亮边/小矩形/套框，不变07覆盖及限幅、06轮廓/短管比例；正常窗口检查优先。
禁止：不变07尺寸/坐标、旧06/08PNG、舰体/底座、生产资源/配置/数值/编队/存档，不接入不合main。
交付：cannon-value-review-09/normal-comparison.png、design-board.png（先八舰/转向后细节）、direction-check.png；入口evidence/cannon-redesign-20261020/README.md。
自查：同尺寸前后/正常八舰与转向检查，钢灰主体和白侧甲分别读到；顶面RGB中值45/49/60→147/157/174，白侧甲244/248/253，不靠细亮线。120几何探针无越界、外接圆间隙约10px；源与生产冻结，未启动Godot。
下一步：Git交设计稿待外观审阅，无执行阻塞。
