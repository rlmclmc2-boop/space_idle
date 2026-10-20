# Cannon redesign
目标：依用户反馈重做独立炮贴图，保留已认可的舰体与固定底座。
范围：炮美术源、导入元数据、隔离预览与必要证据；禁止生产配装/数值/编队变动。
基准：419d5687，分支 art/integrated-rank-hulls-20261020。
停止条件：新炮原尺寸实机证据、最小检查、独立候选提交；不合 main。
定位：art_sources/enemy-fleet-20261019/prepare_ranked_assets.py、assets/weapons/integrated_ranked_20261020、test/test_enemy_ranked_art.gd。
风险：原尺寸缩小后轮廓破碎；检查原尺寸可读性和旋转枢轴。
完成：新炮贴图已替换并通过908检查0失败；8舰体/24底座与生产脚本、数据均冻结。证据evidence/cannon-redesign-20261020；独立分支候选，不合main。无阻塞。
