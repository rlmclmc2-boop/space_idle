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
  galaxyBounds: {"galaxy_core.png":[93,134,226,135],"colony_ring-lv1.png":[112,144,160,113],"colony_ring-lv2.png":[109,145,165,116],"colony_ring-lv3.png":[107,146,170,119],"colony_ring-lv4.png":[104,139,176,130],"colony_ring-lv5.png":[101,140,182,133],"orbital_shipyard-lv1.png":[87,117,209,159],"orbital_shipyard-lv2.png":[83,117,218,163],"orbital_shipyard-lv3.png":[79,117,226,167],"orbital_shipyard-lv4.png":[74,116,236,172],"orbital_shipyard-lv5.png":[70,110,244,182],"stellar_energy_array-lv1.png":[122,150,155,98],"stellar_energy_array-lv2.png":[119,149,161,102],"stellar_energy_array-lv3.png":[102,150,180,110],"stellar_energy_array-lv4.png":[99,149,186,115],"stellar_energy_array-lv5.png":[95,148,194,122],"interstellar_refinery-lv1.png":[126,138,137,113],"interstellar_refinery-lv2.png":[121,138,146,115],"interstellar_refinery-lv3.png":[115,133,156,123],"interstellar_refinery-lv4.png":[110,133,165,125],"interstellar_refinery-lv5.png":[102,131,177,130],"crystal_refinery-lv1.png":[126,143,138,110],"crystal_refinery-lv2.png":[121,143,142,114],"crystal_refinery-lv3.png":[116,144,152,118],"crystal_refinery-lv4.png":[112,144,160,122],"crystal_refinery-lv5.png":[107,144,169,125],"heavy_element_refinery-lv1.png":[120,147,142,111],"heavy_element_refinery-lv2.png":[118,147,148,115],"heavy_element_refinery-lv3.png":[114,145,156,120],"heavy_element_refinery-lv4.png":[110,142,164,126],"heavy_element_refinery-lv5.png":[105,139,174,133],"transport_shuttle.png":[129,167,101,74]},
  amountDisplays: {"1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000":"1.00e+120","30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000":"3.00e+130"},
  previewMounts: [[382.0767,225.4099],[274.8447,452.3739],[493.1042,452.3739]]
};
