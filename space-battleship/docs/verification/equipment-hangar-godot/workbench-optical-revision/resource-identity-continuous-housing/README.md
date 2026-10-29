# 装备共用资源身份与连续壳面候选（待原审）

固定源码 `bcad25d0bfc6eb3c603cc53fad1df21f24ac3e53`，前置 `dc5b6ff63e4f06362ac6220fa7ca2e954ed08753`。根实看退回前置品质后明确要求继续：本次修源壳侧边重复接头、中心与原壳脱节及底部承托紧，同时完成已授权共用资源身份。作者静态实看不代表原Astra/根/用户艺术通过；不pushmain。

[双费用整屏](01-double.png)及[原像素局部](01-double-local.png)、[单费用整屏](02-single.png)及[局部](02-single-local.png)、[批量整屏](03-batch.png)及[局部](03-batch-local.png)全部实际view_image。三整屏为1440×900，局部从同一Godot根viewport按真实控件rect扩4px截取、不缩放或补绘。

原壳640×189，32px角部之间中段125px；旧垂直TILE在当前272px台的局部y157重接，正是费用行上方两侧同高接头。另用单采样色多边形作中心，再依亮度淡出源边的shader，不能消除条带内部重复，也丢失源漆面连续阴影。现在保留相同壳PNG、裁切/初始化缩放、32px固定角部，使用StyleBoxTexture连续九切片STRETCH并draw_center=true；边条和中心都消费同一原图，删除PaintedConsole独立多边形、补缝shader与全部尺寸更新调用。没有新覆盖片、新材质层或资产批。细微中心纹理会随九切片中心缩放；这是一项明确取舍，不声称所有纹理原像素保持。

原台按钮action=height−52，36px高后仅16px，落在32px壳边过渡内。现台高整体增加16px（单费266、双费/异物288），action=height−68，按钮至底32px；底锚896、按钮全局y828..864与原双费相同，报价到按钮间距不压缩。台顶部上移16px，内容仍属唯一Panel；原台面/读数/开放候选/双键层级保留，不恢复通用凹框。观察中两侧重复接头消失、底部留出连续漆面承托；整体质感与内容覆壳感仍交原审判断。

共用身份固定来源 `c4c48282fdc35a38769077c7148d270bde39a8b0`，正常fetch `origin design/clear-zone-host`后读取。必要共享文件只有 `src/ui/resource_visuals.gd` 与其实际引用的5张 `assets/ui/public_shell/resource-{iron,uranium,chrono,jewel,matter}.svg`，六文件逐字该固定对象；13规范仅精确插入§2.2的“资源身份统一”一段，未覆盖整份规范。没有接宿主、公共壳、其他页面或战场实现。

| 业务ID | 名称 | 形状/共享颜色 |
|---|---|---|
| 1 | 铁 | 锭形 / d9b681 |
| 2 | 铀 | 核形 / 8ed4bb |
| chrono | 时空微粒 | 沙漏 / 86cddf |
| jewel | 强化碎片 | 晶体 / b9abf0 |
| degenerate_matter | 简并物质 | 致密球 / b9c8d5 |

装备余额17px、报价20px从同一个ResourceVisuals取Texture2D及modulate；名称/金额继续可见，业务金额由原Amount格式化，不修改价格或显示条件。5种费用节点与5种余额节点在初始化有界创建，后续只填字/定位/显隐；不在数字更新创建图标/Label、不引全局刷新。[mapping.json](mapping.json)只核对缓存五映射、同纹理同颜色与当时真实报价：Lv19铁1600/简并物质10，单费防御65铁。余额三种是既有受控静态fixture，**不是三种消费报价**；未制造第三生产费用、时空或碎片余额。

正式Godot4.7.2、当前main.tscn/Session/native静态采图进程exit0，`RESOURCE_CONTINUOUS_STATIC_COMPLETE failures=0`；不执行购买。最终驱动清空临时引用并等释放帧后退出，无ObjectDB残留警告。前次预览缺native环境导致启动失败与随后临时退出引用残留的原日志、预览驱动均原样归档为preview-*。预览driver仍持app/session/panel引用且只等1帧即quit；正式driver仅清空这些引用并等8释放帧，运行源码字节未变，退出占用提示消失，支持归因于临时驱动生命周期。本轮没有为消告警改Owner或其他运行源码；这不替代长期资源生命周期验证。4.7.2 check-only通过；运行源码及非raw文档diff-check通过。Godot原始check.log尾部空行保留，整批raw证据diff-check会如实报告该尾空行，不为通过空白检查改日志。[源码边界](source-boundaries.json)核对六共享原字节、main/Owner/Session/Economy/Campaign/project/正式机库与两个原材质未变、14个逻辑函数逐字dc5b。

原36项真实运行仍只绑定 `89ac5d0a0a4a124b0dbff9a15b92a50f2a1b9588`，见[旧独立运行记录](../painted-console-rework/runtime-89ac5d0a/operations.json)，不是本轮重跑：单槽/Batch full0/numeric1/options0/stage0/compare1及79节点同ID是旧版本计数；本版初始化增加固定资源控件，不能套用79总节点。循环/候选只comparison、refit/availability必要full的路径保持，wallet渲染调用与壳材质调用是已明示差异；同预算仅静态保留，未新测。未扩全链/全舰/WindowsDPI/长期/自然收入/战场掉落接入/新交易验证。

原workspace、分支/cache、未跟踪import/UID、全部/tmp/原生成素材保留。本接替截至归档未发生实际上下文压缩；原执行者曾实际压缩并停止的边界见旧交接。无新workspace/worktree/子代理/Library/Space/main写入；候选仅Git交根及原审。
