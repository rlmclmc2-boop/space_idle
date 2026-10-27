/* Design response fixtures only. No gameplay formulas, quoting or scheduling run here. */
window.SceneModels = {
  reactor: {
    core: {path:'art/reactor/core.svg', canvas:[512,512], install:[256,434], power_out:[256,464], energy:[257,248]},
    weapons: {path:'art/reactor/weapons.svg', canvas:[512,512], install:[256,434], power_in:[448,336]},
    defence: {path:'art/reactor/defence.svg', canvas:[512,512], install:[256,434], power_in:[64,336]},
    smelting: {path:'art/reactor/smelting.svg', canvas:[512,512], install:[256,434], power_in:[448,336]},
    condensation: {path:'art/reactor/condensation.svg', canvas:[512,512], install:[256,434], power_in:[64,336]}
  },
  research: {
    equipment_finishing: {name:'精密制造',level:1,progress:'68%',work:'36.72 K',required:'54.00 K',speed:'14.4',remaining:'20 分',effect:'武器与防御普通值提升',image:'equipment-precision-v2.png'},
    uranium_extraction: {name:'铀萃取',level:1,progress:'42%',work:'22.68 K',required:'54.00 K',speed:'14.4',remaining:'36 分 15 秒',effect:'原生铀收入提升',image:'uranium-extraction-v2.png'},
    weapon_accuracy: {name:'武器校准',level:21,progress:'24%',work:'16.86 K',required:'70.26 K',speed:'14.4',remaining:'61 分 48 秒',effect:'武器普通伤害提升',image:'weapon-accuracy-v2.png'},
    equipment_reinforcement: {name:'装甲强化',level:21,progress:'12%',work:'3.56 K',required:'29.67 K',speed:'14.4',remaining:'30 分 13 秒',effect:'防御普通容量提升',image:'equipment-reinforcement-v2.png'},
    resource_refining: {name:'资源精炼',level:21,progress:'56%',work:'39.35 K',required:'70.26 K',speed:'14.4',remaining:'35 分 46 秒',effect:'原生铁收入提升',image:'resource-refining-v2.png'},
    singularity: {name:'AI奇点',level:3,progress:'36%',work:'125.97',required:'349.92',speed:'14.4',remaining:'16 秒',effect:'AI数量提升',image:'ai-singularity-v2.png'},
    fragment_condensation: {name:'碎片凝聚',level:0,progress:'0%',work:'0',required:'60',speed:'14.4',remaining:'5 秒',effect:'直接碎片收入提升',image:'fragment-condensation-v2.png'},
    unification: {name:'联合一体化',level:0,progress:'0%',work:'0',required:'1.62 M',speed:'14.4',remaining:'31 小时 15 分',effect:'武器与防御联合因子',image:'joint-integration-v2.png'}
  },
  previewMounts: [[382.0767,225.4099],[274.8447,452.3739],[493.1042,452.3739]]
};
