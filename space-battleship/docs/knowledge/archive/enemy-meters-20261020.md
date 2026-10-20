# enemy-meters-20261020
基准main c45f46c4；仅修八舰血盾条中心对齐/边缘截断，查canonical/retained坐标与实际clip；同画面前后证据、最小受影响检查、独立提交，不合main。禁止改舰体尺寸、编队、战斗数值/中心判定。定位scripts/battlefield.gd:enemy_status_layout,battle_meter；retained_enemy_contacts.gd:update_meters,paint；八舰现有QA。

完成：发现旧outer-wing外侧left偏置+整条clamp；八舰统一中心对称span，边缘对称缩条而不移中心，两条绘制路径共用。固定八舰画面原条仍在clip内，右上anchor中心偏16.6543，scout25.2677/reactive16.6806；修复均0。96检查0失败，实际canvas clip/左右边缘±9shake/canonical-retained一致；before/after舰体rows全等。证据evidence/enemy-meters-20261020。未改舰体/编队/数值/中心，未合main，无阻塞。
