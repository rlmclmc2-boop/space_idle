# 八种普通舰当前单格尺寸对照

只看尺寸，未继续编队重设计。基准ad325818，生产scripts/data/assets/config_excel/addons与基准无差异；只新增QA场景和这张证据图。

`ordinary-eight.png`：默认1373×883窗口的实际主场景原始PNG（回读1372×883），无裁切、缩放或拼贴。当前5×3区域572×400，单格114.4×133.333逻辑单位，在图中约80×94实际像素。8舰均为普通1×1格，保持现有显示比例及血盾条，QA名牌用于逐舰比较。

上排：scout、sentry、interceptor、swarm、anchor。第二排：reactive、shielded、command。没有精英/BOSS单位，也没有应用重设计方案。

真实main.tscn隔离存档QA编队已实际交火并结算伤害，之后暂停、只在QA中清理瞬时弹道和浮字，方便比较舰体；没有修改生产编队或数值。266项边界/血盾/中心/帧消费检查零失败。图片是否达到所需识别度留给本次尺寸评审决定，不据此宣称美术已验收。

重设计尚未产生代码/配置改动；唯一任务记录单独保存在wip/enemy-formation-design-paused分支36c828f2，不混入本次提交。复现：隔离项目运行test/test_enemy_grid_layout.gd，GRID_CASE=ordinary-eight，GRID_OUTPUT指定输出，图形模式及隔离XDG。当前本地Godot4.6.3 Linux/GDS路径。
