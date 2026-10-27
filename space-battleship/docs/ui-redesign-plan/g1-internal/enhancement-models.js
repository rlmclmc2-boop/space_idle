/* Controlled read-only presentation samples; gameplay/quotes remain Enhancement-owned. */
window.EnhancementModels={
 effects:{
 proficiency:{name:'熟练',symbol:'⌁',summary:'规范攻击历史提高普通武器值',a:'伤害 +50%；已生效A节点先相加',b:['同一主目标每整1秒再 ×1.2；换目标清计时','武器攻击周期 ×0.7','把匹配敌抗性的减伤改为30%']},
 repeat:{name:'连发',symbol:'↝',summary:'50%触发0.5秒后额外攻击；本级伤害 ×7',a:'连发触发率 +10百分点',b:['主命中额外连锁1个目标','此节点B不启用第二代连发；旧选择保留','普通攻击20%另锁1个目标；无额外目标则不发']},
 critical:{name:'暴击',symbol:'✧',summary:'基础暴击率25%；额外暴伤按有效等级增长',a:'暴击率 +15百分点',b:['暴击后后续3次规范攻击伤害 +50%','暴击叠层，上限3；每层率+5百分点、伤害+10%，持续2秒','暴击效果触发率100%；额外暴伤仍按原始暴击率R判定，强制补足不附赠爆伤']},
 adaptation:{name:'适应',symbol:'⬡',summary:'来袭历史提高最大防御值',a:'最大防御 +50%；已生效A节点先相加',b:['同敌后续来袭每层原伤 −20%，最多3层；来源死亡清除','每2秒生成1秒无抗性护罩；容量=自身最大防御+记忆上限','原本存在的匹配抗性 +25百分点，钳1；不赠中性抗性']},
 memory:{name:'记忆材料',symbol:'≋',summary:'每0.2秒修复最大值的30%；满后充能保护',a:'恢复与记忆保护上限 +20%；已生效A节点先相加',b:['全局恢复跳有正恢复时10%触发共享50%减伤1秒','同类来袭赋予该类50%保护抗性2秒；异类清除并禁获2秒','每启用盾模块使记忆充能+40%；每装甲模块使保护上限+40%']},
 deferred:{name:'延迟伤害',symbol:'◴',summary:'延期2秒，每0.2秒结算；全局25%随机清队',a:'全局清队概率 +10百分点；每节点只计一次',b:['清队后共享原伤 −20%持续1秒','禁用随机清除，未强制清除概率 ×0.5转减伤','强制清队；来袭伤害 ×[1+(1−未强制清除概率)]']}
 },
 positions:[{effectGate:1,nodeGates:[10,20,30]},{effectGate:10,nodeGates:[20,30,40]},{effectGate:20,nodeGates:[30,40,50]}],
 quotes:{one:{count:1,price:'13.42 B',balance:'50.58 B',paid:28,effective:31},ten:{count:2,price:'40.26 B',balance:'23.74 B',paid:29,effective:32}},
 notice:'E30/E31/E32 demonstration snapshots only; effect values for changed level must be refreshed from owner. Purchase fixtures are not a fee formula.'
};
