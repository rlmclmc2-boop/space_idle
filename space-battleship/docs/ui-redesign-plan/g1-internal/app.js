const $ = selector => document.querySelector(selector);
const asset = '../../../assets/';
const modules = [
  ['equipment', '舰体与装备', 'HULL / OUTFITTING'],
  ['reactor', '反应炉', 'POWER / DISTRIBUTION'],
  ['research', '科研工厂', 'RESEARCH / AI LAB'],
  ['enhancement', '强化', 'ENHANCEMENT'],
  ['crew', '船员', 'CREW / ASSIGNMENTS'],
  ['planet', '星球', 'PLANET / EXPLORATION'],
  ['galaxy', '星系', 'GALAXY / DEVELOPMENT'],
  ['hyperspace', '超空间', 'HYPERSPACE'],
  ['archive', '档案', 'ARCHIVE'],
  ['settings', '设置与保存', 'SYSTEM / PERSISTENCE']
];
const state = {
  family: 'scene', module: 'reactor', route: 'reactor', group: 'combat',
  groupLast: {combat: 'reactor', colony: 'planet', hyperspace: 'hyperspace/routes', maintenance: 'settings'},
  moduleLast: {}, trail: [], scroll: {}, collapsed: false, paused: false,
  reactor: 'running', equipment: 'normal', planet: 'building', galaxy: 'building',
  alloc: [45,35,20,0], actual: [45,35,20,0], reactorError: '', reactorReceipt: '', reactorFailAt: -1, reactorIntent: 'custom',
  slot:0, fitKeys:['laser','missile','longLaser','shield','armour'], levels: [24,18,18,18,18], fits: ['脉冲炮','舰载导弹','长激光','护盾发生器','装甲'],
  attributes:['12.4 K','12.4 K','12.4 K','84.0 K','84.0 K'], candidate: false, equipmentMode: 'one', planetAuto: true, planetId: '1', galaxyNode: '9', galaxyNodes:structuredClone(ColonyModels.galaxy.nodes), galaxyView:{x:0,y:0,zoom:1.3}, planets: structuredClone(ColonyModels.planets), crewPlanet:'1', crewFacility:'shipyard', crewMode:'1', crewError:'',
  crewId: 'navigator', crewDraft: 'planet-build',
  crewMembers: structuredClone(ColonyModels.crew),
  researchId:'equipment_finishing', researchBudget:'800000', researchDraft:'800000', researchUranium:'120000', researchUraniumDraft:'120000', researchAuto:false, researchRatio:'25', researchAutoDraft:false, researchRatioDraft:'25', researchState:'running', researchDrawer:false, researchUnlocked:['equipment_finishing','uranium_extraction','weapon_accuracy','equipment_reinforcement','resource_refining','singularity'], researchError:'', researchFeedback:'', researchIntent:25, cooldowns:{},
  droneId: 'd2', droneSelection: ['d2'], equippedDrones: ['d1'], formationDraft: ['d2'], formationPreview: null,
  forgePreview: null, forgeResult: null, forgeOperation: 'reroll',
  filter: {quality: '稀有以下', action: '保留'}, filterDraft: {quality: '稀有以下', action: '保留'},
  materialDraft: '100', materialReceipt: '', routeId:'pulse', manualTask:{status:'idle',route:'pulse',run:'manual-01',receipt:null}, onlineTask:{status:'idle',route:'missile',run:'online-01',receipt:null,mode:'single',crewId:null},
  dangerKind: 'reforge', dangerSource: '起源星', dangerPreview: null, dangerResult: null,
  enhance:{paid:27,extra:3,effective:30,weapon:['proficiency','repeat','critical'],defence:['adaptation','memory','deferred'],branches:{proficiency:['A','B','A'],repeat:['A','B',''],critical:['B','',''],adaptation:['A','B',''],memory:['B','A',''],deferred:['B','','']},effect:'proficiency',node:0,choice:'',purchaseMode:'one',funds:false,feedback:'',quoteUsed:false},
  maintenance:{save:'saved',directory:'D:/SpaceIdle/save',directoryDraft:'D:/SpaceIdle/save',music:true,effects:true,damage:'all',interval:'60',skip:false,feedback:'',dangerError:'',importSource:'backup-02.json',newDirectory:'D:/SpaceIdle/new-voyage',clearSettings:false,retained:['d2'],previewSerial:0},
  archive:{tab:'tutorial',tutorial:'equip',completed:['equip','pickup'],guidePaused:false,enemy:'enemy-demo-1',notifications:[{key:'unlock:crew_06',title:'船员开放 · 无限大',seen:false,read:false},{key:'research:equipment_finishing',title:'精密制造研究完成',seen:false,read:false}],intel:[{id:'enemy-demo-1',name:'护卫舰',tier:'普通',image:'01-frigate.png',armour:'12.0 K',shield:'0',mechanics:'当前护盾已耗尽；装甲仍可承伤。'},{id:'enemy-demo-2',name:'驱逐舰',tier:'精英',image:'02-destroyer.png',armour:'28.0 K',shield:'16.0 K',mechanics:'护盾与装甲分别承伤；护盾耗尽后余伤进入装甲。'}]},
  notice: '舰桥就绪'
};
const groups = {
  combat: {name:'战力维护', roots:['equipment','reactor','research','enhancement'], cards:[['equipment','配装'],['reactor','供能'],['research','科研']]},
  colony: {name:'殖民推进', roots:['crew','planet','galaxy'], cards:[['crew','人员'],['planet','星球'],['galaxy','星系']]},
  hyperspace: {name:'超空间收获', roots:['hyperspace','crew'], cards:[['hyperspace/routes','任务'],['hyperspace/formation','无人机编队'],['crew','人员']]},
  maintenance: {name:'航行维护', roots:['settings','archive'], cards:[['settings','保存'],['settings/danger/reforge','危险事务'],['archive','档案']]}
};
const drones = {
  d1: {name:'巡航者·脉冲', weapon:'脉冲炮', quality:'史诗', level:24, affix:'攻击 +8%', icon:'pulse.png'},
  d2: {name:'猎隼·导弹', weapon:'导弹', quality:'稀有', level:18, affix:'暴击 +4%', icon:'missile.png'},
  d3: {name:'棱镜·光束', weapon:'长激光', quality:'史诗', level:20, affix:'射速 +6%', icon:'beam.png'}
};
const equipmentResponses={
  '24.2 K':{ten:'36.0 K',one:'25.0 K',max:'34.2 K'},'25.0 K':{one:'25.8 K',max:'35.3 K'},'116.0 K':{ten:'148.0 K',one:'119.2 K',max:'129.0 K'},
  '12.4 K':{ten:'24.2 K',one:'13.1 K',max:'16.3 K'},'13.1 K':{one:'13.8 K',max:'16.9 K'},'13.8 K':{one:'14.5 K',max:'17.6 K'},
  '14.5 K':{one:'15.2 K',max:'18.3 K'},'16.3 K':{one:'16.9 K',max:'20.4 K'},'15.8 K':{one:'16.5 K',max:'19.6 K'},
  '84.0 K':{ten:'116.0 K',one:'87.2 K',max:'96.0 K'},'87.2 K':{one:'90.4 K',max:'99.2 K'},'92.0 K':{one:'95.2 K',max:'104.0 K'},'96.0 K':{one:'99.2 K',max:'108.0 K'}
};
const studies = SceneModels.research;
const jobs = {idle:'空闲', 'planet-build':'星球设施施工', 'planet-explore':'星球探索', galaxy:'第一星系建设', hyperspace:'超空间在线挂机保留', research:'AI科研续研岗位',equipment:'装备自动购级',enhancement:'强化自动购级',reactor:'反应炉自动购级'};
const planetStatus = {building:['施工中','62%','后续施工完成后等待领取'],paused:['缺少施工人员','62%','施工次数已保留'],ready:['待领取','100%','领取后设施收益才生效'],owned:['已领取','100%','轨道船坞收益已计入当前Buff']};
const galaxyStatus = {building:['建设中','62%','工程推进取决于当前人员'],fog:['未探索','0%','父节点尚未探索完成'],planned:['规划地基','0%','探索可达后进入工程'],upgrading:['升级中 · Lv.2仍生效','48%','升级完成后自动更新收益'],complete:['已建成 Lv.3','100%','收益已生效，无需领取']};
const effectSnapshots = {
  '0,0,0,0': {attack:'×1.02', defence:'×1.00', income:'×1.00'},
  '34,33,33,0': {attack:'×1.20', defence:'×1.19', income:'×1.26'},
  '25,25,25,25': {attack:'×1.14', defence:'×1.15', income:'×1.22'},
  '45,35,20,0': {attack:'×1.28', defence:'×1.21', income:'×1.18'},
  '45,35,5,0': {attack:'×1.28', defence:'×1.21', income:'×1.05'},
  '60,35,5,0': {attack:'×1.40', defence:'×1.21', income:'×1.05'},
  '40,40,20,0': {attack:'×1.24', defence:'×1.25', income:'×1.18'}
};
const control = (action,label,cls='',disabled=false) => `<button data-action="${action}" class="${cls}" ${disabled?'disabled':''}>${label}</button>`;
const sum = values => values.reduce((a,b)=>a+b,0);
const changed = () => state.alloc.some((v,i)=>v!==state.actual[i]);
const crewCount = (job,planetId=null,facilityId=null) => Object.values(state.crewMembers).filter(m=>m.available&&m.job===job&&(!planetId||m.targetPlanet===planetId)&&(!facilityId||m.targetFacility===facilityId)).length;
const selectedPlanet=()=>state.planets.find(p=>p.id===state.planetId);
const selectedFacility=()=>selectedPlanet().facilities[selectedPlanet().facilitySelection];
function memberJob(m){if(m.job.startsWith('planet-')){const p=state.planets.find(p=>p.id===m.targetPlanet);return p.name+' / '+(m.job==='planet-build'?p.facilities[m.targetFacility].name+'施工':'探索');}return jobs[m.job];}
function crewAdmission(){const m=state.crewMembers[state.crewId];if(m.job==='hyperspace')return '该成员被在线任务保留，请从任务入口停止或领取后再派遣。';if(state.crewDraft==='planet-build'){const p=state.planets.find(p=>p.id===state.crewPlanet),f=p.facilities[state.crewFacility];if(f.state!=='building')return '所选设施当前不在施工。';if(!f.extraCrew)return '此设施不需额外施工人员，由探索完成推进。';if(Object.entries(state.crewMembers).filter(([id,x])=>id!==state.crewId&&x.job==='planet-build'&&x.targetPlanet===p.id&&x.targetFacility===f.id).length>=f.extraCrew)return '所选设施额外施工岗位已满。';}else if(state.crewDraft!=='idle'){const cap=state.crewDraft==='galaxy'?6:1;const others=Object.entries(state.crewMembers).filter(([id,x])=>id!==state.crewId&&x.job===state.crewDraft&&(x.job!=='planet-explore'||x.targetPlanet===state.crewPlanet)).length;if(others>=cap)return '所选目标人数已达容量 '+cap+'。';}return '';}

let renderedRoute=null, renderedCollapsed=false;
const escapeText = s => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function notify(text) { state.notice=text; $('#notice').textContent=text; }
function rememberScroll() {
  if(state.collapsed) return;
  state.scroll[state.route] = {outer:$('#work-content')?.scrollTop||0, inner:$('.work-sheet')?.scrollTop||0};
}
function goRoute(route, options={}) {
  rememberScroll();
  if (options.history!==false && route!==state.route) state.trail.push({route:state.route,group:state.group});
  if (options.group) state.group=options.group;
  const root=route.split('/')[0];
  if (root!=='catalog' && !groups[state.group].roots.includes(root)) {
    state.group=Object.keys(groups).find(id=>groups[id].roots.includes(root))||state.group;
  }
  state.route=route; state.module=root; state.collapsed=false;
  if(root!=='catalog') {state.moduleLast[root]=route; state.groupLast[state.group]=route;}
  render();
}
function setModule(id) { goRoute(state.moduleLast[id]|| (id==='hyperspace'?'hyperspace/routes':id)); }
function back() {
  const previous=state.trail.pop();
  if(previous) goRoute(previous.route,{group:previous.group,history:false});
}
function switchGroup(id) {goRoute(state.groupLast[id],{group:id});}
function moduleHead(title,sub,tag='') {
  const en=modules.find(row=>row[0]===state.module)?.[2]||'OPERATIONS';
  return `<div class="pagehead"><div><span class="eyebrow">${en}</span><h1>${title}</h1><div class="sub">${sub}</div></div>${tag}</div>`;
}
function nav() {
  if(state.family==='scene') return modules.map(([id,name])=>`<button data-module="${id}" class="${state.module===id?'active':''}">${name}</button>`).join('');
  return Object.entries(groups).map(([id,g])=>`<button data-group="${id}" class="${state.group===id?'active':''}">${g.name}</button>`).join('')+control('catalog','全系统索引');
}
function summary(route) {
  if(route==='equipment') return `${state.slot<3?'武器'+(state.slot+1):'防御'+(state.slot-2)} · ${state.fits[state.slot]} Lv.${state.levels[state.slot]}${state.candidate?' / 有候选':''}`;
  if(route==='reactor') return `${sum(state.actual)}/100${changed()?' · 草稿'+sum(state.alloc):' · 已生效'}`;
  if(route==='research') return `${studies[state.researchId].name} · 铁${state.researchBudget}/秒${state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium?' / 有草稿':''}`;
  if(route==='crew') {if(state.group==='hyperspace'){const task=state.onlineTask;return task.crewId?state.crewMembers[task.crewId].name+' · '+routeName(task.route)+' / '+taskStatus(task):'当前在线任务无保留船员';}const m=state.crewMembers[state.crewId];return `${m.name} · ${memberJob(m)}`;}
  if(route==='planet') return `${selectedPlanet().name} · ${selectedFacility().name} / ${facilityStatus(selectedPlanet(),selectedFacility())}`;
  if(route==='galaxy'){const n=state.galaxyNodes[state.galaxyNode];return `${n.name} · ${galaxyStatus[n.state][0]}`;}
  if(route==='hyperspace/routes') return `手动·${routeName(state.manualTask.route)} ${taskStatus(state.manualTask)} / 挂机·${routeName(state.onlineTask.route)} ${taskStatus(state.onlineTask)}`;
  if(route==='hyperspace/formation') return `${state.equippedDrones.map(id=>drones[id].name).join(' / ')}${state.formationDraft.join()!==state.equippedDrones.join()?' · 有候选':''}`;
  if(route==='settings/danger/reforge') return state.dangerPreview?'预览待确认':state.dangerResult?'最近结果可查':'重铸 / 导入 / 新游戏';
  if(route==='archive') return ({tutorial:'飞行手册',intel:'当前敌情',notifications:'通知档案',statistics:'伤害明细'})[state.archive.tab]+' · 未读'+state.archive.notifications.filter(n=>!n.read).length;
  if(route==='settings') return MaintenanceModels.saveStates[state.maintenance.save].title;
  return '敌情 / 通知 / 教程';
}
function workWrapper(body) {
  const g=groups[state.group];
  return `<div class="context-strip">${g.cards.map(([route,title])=>`<button class="context-object ${state.route===route||(!route.includes('/')&&state.module===route&&!(route==='settings'&&state.route.includes('/danger/')))?'active':''}" data-context-route="${route}"><b>${title}</b><span>${summary(route)}</span></button>`).join('')}</div><section class="work-sheet">${body}</section>`;
}
function reactor() {
  const ids=['weapons','defence','smelting','condensation'];
  const names=['武器增幅舱','防御发生舱','资源熔炼舱','碎片凝聚舱'];
  const free=state.reactor==='idle'?0:10, opened=state.reactor==='opened';
  const before=effectSnapshots[state.actual.join()], after=effectSnapshots[state.alloc.join()];
  const keys=['attack','defence','income','income'];
  const machine=i=>{
    const art=SceneModels.reactor[ids[i]],powered=state.actual[i]+(i===0?free:0)>0;
    return `<figure class="device-workpoint device-${ids[i]} ${powered?'powered':'unpowered'}" data-device="${i}" data-port-x="${art.power_in[0]}" data-port-y="${art.power_in[1]}"><figcaption><b>${names[i]}</b><small>${i===2?'敌掉铁基础量':i===3?'直接碎片':i===0?'武器普通值':'防御普通值'} ${before?.[keys[i]]||'待效果读数'}${changed()?` → <strong>${after?.[keys[i]]||'待预览'}</strong>`:''}</small></figcaption><img src="${art.path}" alt="${names[i]}独立设备"><div class="machine-readout"><span>${powered?'供能中':'待机'}</span><b data-readout="manual_supply">${state.actual[i]}</b><small data-readout="free_supply">免费 ${i===0?free:0}</small><small data-readout="effective_supply">有效 ${state.actual[i]+(i===0?free:0)}</small></div><div class="machine-controls"><label>${names[i].slice(0,2)}占手动容量 <b>${state.alloc[i]}%</b><input type="range" min="0" max="100" value="${state.alloc[i]}" data-reactor-share="${i}" aria-label="${names[i]}占手动容量比例"></label>${control('reactor-amount-'+i,'精确值','quiet')}</div></figure>`;
  };
  return moduleHead('反应炉机舱','核心 Lv.1 · 手动预算100 · 免费供能'+free,`<span class="pill ${changed()?'warn':''}">${changed()?'分配待应用':'当前已生效'}</span>`)+
    `<div class="allocation-task"><div><b>保持防御，优先武器供能</b><span>从熔炼暂调15单位到武器；核心容量不变。</span></div>${control('reactor-task','查看调配方案')}</div>`+
    `<div class="reactor-room"><div class="reactor-grid reactor-room-grid"><svg class="reactor-pipes ${!state.paused&&sum(state.actual)>0?'running':''}" aria-label="核心出口、主管、设备入口统一连接"></svg>${machine(0)}${machine(2)}<div class="reactor-core-assembly ${sum(state.actual)+free>0&&!state.paused?'running':''}"><img src="${SceneModels.reactor.core.path}" alt="反应炉独立核心"><div class="reactor-energy"></div><div class="core-instrument"><small>当前有效供能</small><b>${sum(state.actual)+free}</b></div></div>${machine(1)}${opened?machine(3):''}<span class="trunk-label">供能主管</span></div></div>`+
    (state.reactorReceipt?`<div class="note">${state.reactorReceipt}</div>`:'')+
    (state.reactorError||sum(state.alloc)>100?`<div class="note bad">${state.reactorError||'草稿超过手动预算，当前实际供能不变。'}</div>`:'')+
    `<div class="secondary-actions">${control('reactor-equal','均分')}${control('reactor-clear','清零草稿')}${control('reactor-buy','核心升级 · 10 铀','quiet')}</div>`;
}

function reactorNextCommand() {
  const differences=state.alloc.map((target,index)=>({index,target,current:state.actual[index]})).filter(row=>row.target!==row.current);
  const command=differences.find(row=>row.target<row.current)||differences[0];
  if(!command) return null;
  const next=[...state.actual];next[command.index]=command.target;
  return {...command,next};
}
const equipmentNames={laser:'脉冲炮',missile:'舰载导弹',longLaser:'长激光',cannon:'舰炮',shield:'护盾发生器',armour:'装甲'};
const equipmentCycles={laser:'0.8秒',missile:'1.2秒',longLaser:'持续光束',cannon:'1.4秒'};
function candidateType(){return state.slot<3?(state.fitKeys[state.slot]==='cannon'?'laser':'cannon'):(state.fitKeys[state.slot]==='shield'?'armour':'shield');}
function slotIcon(){return 'cartoon_'+state.fitKeys[state.slot]+'.svg';}
function comparisonCycle(){const current=equipmentCycles[state.fitKeys[state.slot]];return state.slot<3?'攻击周期 '+current+(state.candidate?' → '+equipmentCycles[candidateType()]:'（保持）'):'防御类型 '+equipmentNames[state.fitKeys[state.slot]]+(state.candidate?' → '+equipmentNames[candidateType()]:'（保持）');}
function currentCooldown() {return state.cooldowns[state.slot]||0;}
function equipmentQuote() {
  const defence=state.slot>=3, current=state.attributes[state.slot],response=equipmentResponses[current];
  const candidate=state.candidate||state.equipment==='compare';
  if(candidate) return {label:'更换为'+equipmentNames[candidateType()], current, next:defence?(candidateType()==='armour'?'92.0 K':'84.0 K'):(candidateType()==='cannon'?'15.8 K':'12.4 K'), price:'1.8 M 铁 + 材料20', action:'equip-apply'};
  if(state.equipmentMode==='ten') return {label:'购买10级',current,next:response?.ten||'待取得新报价',price:response?.ten?'5.80 M 铁':'待报价',action:'equip-buy'};
  if(state.equipmentMode==='max') return {label:'本槽MAX · 4级',current,next:response?.max||'待取得新报价',price:'2.10 M 铁',action:'equip-buy'};
  return {label:'购买1级',current,next:response?.one||'待取得新报价',price:'0.42 M 铁',action:'equip-buy'};
}
function equipment() {
  const q=equipmentQuote();
  const mounts=SceneModels.previewMounts;
  const point=(i)=>{const p=mounts[i];return {x:50+(p[0]-384)/768*100,y:50+(p[1]-384)/768*100};};
  return moduleHead('巡洋舰 · 装配台','3个武器槽 / 2个防御槽',`<span class="pill">${state.fits[state.slot]} · Lv.${state.levels[state.slot]}</span>`)+
    `<div class="outfit-room"><div class="outfit-rig"><div class="rig-floor"></div><div class="rig-ship"><img src="${asset}ui/ships/fleet_20261019/03-cruiser.png" alt="巡洋舰完整静态预览">${mounts.map((p,i)=>{const a=point(i);return `<button class="mount-dot ${state.slot===i?'selected':''}" data-slot="${i}" style="left:${a.x}%;top:${a.y}%" aria-label="选择武器槽${i+1}">${i+1}</button>`;}).join('')}</div><div class="rig-weapon-labels">${[0,1,2].map(i=>`<button data-slot="${i}" class="rig-slot ${state.slot===i?'selected':''}"><small>武器 ${i+1}</small><b>${state.fits[i]}</b><span>Lv.${state.levels[i]}</span></button>`).join('')}</div><div class="rig-defence-labels">${[3,4].map(i=>`<button data-slot="${i}" class="rig-slot ${state.slot===i?'selected':''}"><small>${i===3?'首防御 · 必装':'防御 2'}</small><b>${state.fits[i]}</b><span>Lv.${state.levels[i]}</span></button>`).join('')}</div></div><div class="outfit-console"><span class="eyebrow">${state.slot<3?'WEAPON '+(state.slot+1):'DEFENCE '+(state.slot-2)}</span><h2>${state.fits[state.slot]}</h2><div class="equipment-object-icon"><img src="${asset}ui/equipment/${slotIcon()}" alt=""></div><div class="compare-cols"><div><small>当前${state.slot<3?'普通攻击基值':'容量'}</small><b>${q.current}</b></div><div><small>${q.label}</small><b>${q.next}</b></div></div><div class="comparison-cadence">${comparisonCycle()}</div><div class="compare-price">本次费用<b>${q.price}</b></div><div class="purchase-modes">${control('equip-one','+1',state.equipmentMode==='one'&&!state.candidate?'active':'')}${control('equip-ten','+10',state.equipmentMode==='ten'&&!state.candidate?'active':'')}${control('equip-max-mode','MAX',state.equipmentMode==='max'&&!state.candidate?'active':'')}</div><p class="sub">${state.slot===3?'首防御槽不可卸空，可换合法防御类型。':state.candidate?'候选未生效；确认后再更新当前装配。':'槽位等级在更换装备后保留。'}</p></div></div>`+
    (currentCooldown()?`<div class="note warn">武器/防御槽${state.slot<3?state.slot+1:state.slot-2}换装冷却剩余${currentCooldown()}游戏秒，其他槽位分别判断。</div>`:'')+
    (state.equipment==='poor'?`<div class="note bad">铁不足，本次需要${q.price}。所选槽位保持。</div>`:'')+
    `<div class="secondary-actions">${control('hull','比较五舰')}${control('equip-all','全部槽位批量预览')}${control('attributes','属性与贡献明细','quiet')}</div>`;
}

function facilityStatus(p,f){if(f.state==='building'){if(!p.running)return '缺少进行中的探索';if(f.extraCrew&&crewCount('planet-build',p.id,f.id)<f.extraCrew)return '缺少额外施工人员';return '施工中';}return {locked:'未达探索门槛',ready:'待领取',owned:'已领取 · 收益生效'}[f.state];}
function planet() {
  const p=selectedPlanet(),f=selectedFacility(),pct=Math.round(f.work/f.required*100),status=facilityStatus(p,f);
  return moduleHead(p.name,'探索度 '+p.exploration+' · 当前设施：'+f.name,`<select id="planet-select" aria-label="选择星球">${state.planets.filter(p=>p.available).map(p=>`<option value="${p.id}" ${p.id===state.planetId?'selected':''}>${p.name}</option>`).join('')}</select>`)+
    `<div class="orbital-room"><div class="orbital-stage ${p.running?'exploring':'stopped'} ${p.stellar?'stellar':''}"><div class="orbital-ellipse"></div><div class="planet-globe" style="--planet-size:${Math.min(p.radiusScale,1.22)*230}px;--atmosphere:#${p.atmosphere}"><img src="${p.surface.replace('res://assets/',asset)}" alt="${p.name}">${p.cloudOpacity?`<img class="cloud-layer" style="opacity:${p.cloudOpacity}" src="${p.cloud.replace('res://assets/',asset)}" alt="独立云层">`:''}</div>${p.running?`<img class="orbital-scout" src="${asset}planets/orbital/scout-v1.png" alt="正在探索的探索机">`:''}${Object.values(p.facilities).map((x,i)=>`<button data-facility="${x.id}" class="orbit-facility orbit-position-${i} ${x.state} ${x.id===f.id?'selected':''}"><img src="${x.icon.replace('assets/',asset)}" alt=""><b>${x.name}</b><small>${facilityStatus(p,x)}</small></button>`).join('')}<div class="exploration-readout"><b>${p.running?'本次探索 '+p.elapsed+' / '+p.duration+' 游戏秒':'探索已停止'}</b><span>探索人员 ${crewCount('planet-explore',p.id)} / 1 · ${p.automatic?'完成后继续':'本次完成后停止'}</span></div></div><div class="facility-console"><span class="eyebrow">ORBITAL DEVELOPMENT</span><h2>${f.name}</h2><span class="pill ${status==='施工中'||f.state==='owned'?'good':'warn'}">${status}</span><div class="facility-work"><b>${f.work} <small>/ ${f.required}次</small></b><div class="meter"><i style="width:${pct}%"></i></div></div><dl><dt>探索门槛</dt><dd>${f.threshold} / 当前${p.exploration}</dd><dt>额外施工人员</dt><dd>${crewCount('planet-build',p.id,f.id)} / ${f.extraCrew}</dd><dt>${f.state==='owned'?'当前收益':'领取后收益'}</dt><dd>${f.effectSummary}</dd></dl><p class="sub">${f.state==='building'?'探索完成一次，已处于施工且人员满足的设施推进一次。':f.state==='ready'?'施工已完成；领取前不计入收益。':f.state==='locked'?'达到门槛后才进入施工，跨门槛那次不提前施工。':'本设施收益已计入当前星球。'}</p>${control('planet-explorer','查看探索人员','quiet')}</div></div><div class="secondary-actions">${control('planet-auto',p.automatic?'本次完成后停止':'开启自动探索','',!p.running)}${control('planet-cancel','立即取消探索','danger',!p.running)}${control('planet-buff','累计Buff / 重铸')}</div>`;
}
const galaxyPoint=n=>({x:400+(n.x-n.z)*2.3,y:270+(n.x+n.z)*1.1});
const galaxyEffect={colony_ring:'船员经验贡献',orbital_shipyard:'装备普通属性贡献',stellar_energy_array:'反应炉容量贡献',interstellar_refinery:'铁自动收入比例',crystal_refinery:'直接碎片贡献',heavy_element_refinery:'铀自动收入比例'};
function galaxy() {
 const n=state.galaxyNodes[state.galaxyNode],view=state.galaxyView;
 const point=id=>id==='hub'?{x:400,y:270}:galaxyPoint(state.galaxyNodes[id]);
 const status=galaxyStatus[n.state][0];
 return moduleHead('第一星系 · 城市发展','区域一 · '+n.name,`<span class="pill">工程人员 ${crewCount('galaxy')} / 6</span>`)+`<div class="city-room"><div class="city-map" tabindex="0" aria-label="星系地图，可平移缩放"><svg viewBox="0 0 800 550"><defs><pattern id="city-grid" width="45" height="24" patternUnits="userSpaceOnUse"><path d="M0 12L22.5 0L45 12L22.5 24Z" fill="none" stroke="#b8c9bd" stroke-width=".5"/></pattern></defs><rect width="800" height="550" fill="url(#city-grid)"/><g id="city-transform" transform="translate(${view.x} ${view.y}) translate(400 270) scale(${view.zoom}) translate(-400 -270)">${ColonyModels.galaxy.links.map(([a,b])=>{const x=point(a),y=point(b);return `<path d="M${x.x} ${x.y}L${y.x} ${y.y}" stroke="#aabdb0" stroke-width="8"/><path d="M${x.x} ${x.y}L${y.x} ${y.y}" stroke="#e1e4d8" stroke-width="4"/>`;}).join('')}<image href="art/galaxy/galaxy_core.png" x="328" y="174" width="144" height="144"/><text x="400" y="310" text-anchor="middle" class="city-hub-label">总部</text>${Object.values(state.galaxyNodes).sort((a,b)=>galaxyPoint(a).y-galaxyPoint(b).y).map(x=>{const q=galaxyPoint(x);const src='art/galaxy/'+x.family+'-lv'+x.level+'.png';return `<g data-galaxy-node="${x.id}" class="city-node ${x.state} ${x.id===n.id?'selected':''}" transform="translate(${q.x} ${q.y})"><ellipse class="city-platform" cx="0" cy="0" rx="37" ry="17"/>${x.state==='fog'?'<text y="4" text-anchor="middle" class="fog-mark">?</text>':x.state==='planned'?'<path d="M-24 0L0 -12L24 0L0 12Z" fill="none" stroke="#85a59a" stroke-dasharray="3 3"/>':`<image href="${src}" x="-49" y="-70" width="98" height="98" ${x.state==='building'?'opacity=".65"':''}/>`}${x.state==='building'||x.state==='upgrading'?`<path d="M-31 -38L-31 -63L31 -63L31 -38M0 -63V-78" stroke="#d0a66a" fill="none" stroke-width="3"/><rect x="-27" y="18" width="54" height="3" fill="#c6cec1"/><rect x="-27" y="18" width="${54*x.progress/100}" height="3" fill="#4d9989"/>`:''}<text y="35" text-anchor="middle">${x.state==='fog'?'未探索':x.name.split(' ')[0]+' · '+(x.state==='planned'?'地基':'Lv.'+x.level)}</text></g>`;}).join('')}<image href="art/galaxy/transport_shuttle.png" x="386" y="326" width="40" height="40" class="city-shuttle"/></g></svg><div class="city-map-tools">${control('galaxy-zoom-out','−')}${control('galaxy-reset','归位')}${control('galaxy-zoom-in','＋')}</div></div><div class="city-console"><span class="eyebrow">SELECTED SITE / ${n.id}</span><h2>${n.state==='fog'?'未探索节点':n.name}</h2><span class="pill ${n.state==='complete'?'good':'warn'}">${status}</span>${n.state==='fog'?'<p>父节点达到可达条件后揭示。设施类型与效果保持隐藏。</p>':`<div class="city-object"><img src="art/galaxy/${n.family}-lv${n.level}.png" alt="${n.name}" style="opacity:${n.state==='planned'?'.35':'1'}"></div><div class="city-node-progress"><b>${n.progress}%</b><span>${n.state==='upgrading'?'当前Lv.'+n.level+'仍贡献，目标Lv.'+n.targetLevel:n.state==='complete'?'已生效 · 无需领取':n.state==='planned'?'已可达，等待自动工程调度':'建设中'}</span></div><div class="meter"><i style="width:${n.progress}%"></i></div><p>${galaxyEffect[n.family]}</p><small>${n.state==='upgrading'?'完成边界升一级并更新贡献。':n.state==='complete'?'当前级贡献已被接纳。':'当前设施尚不贡献收益。'}</small>`}</div></div><div class="secondary-actions">${control('galaxy-region','区域与发展汇总')}${control('galaxy-effects','当前节点效果明细')}</div>`;
}
// Mock Amount boundary: fixture income is canonical integer text; no research speed formula.
const budgetIncome={iron:'3200000',uranium:'480000'};
const budgetWallet={iron:'128600000',uranium:'8400000'};
function budgetPreview(ratio){
  return ['iron','uranium'].map(id=>{const rate=BigInt(budgetIncome[id])*BigInt(ratio)/100n;return {id,rate:String(rate),left:String(BigInt(budgetIncome[id])-rate),reserve:String(rate?BigInt(budgetWallet[id])/rate:0n)};});
}
function researchIntentPanel(){
 const rows=budgetPreview(state.researchIntent);
 return `<div class="budget-intent"><div><b>按近期收入安排投入</b><span>近60游戏秒平均收入 · 铁3.20 M / 秒 · 铀480 K / 秒</span></div><label>共同收入比例 <output>${state.researchIntent}%</output><input id="research-intent" type="range" min="0" max="100" step="1" value="${state.researchIntent}" aria-label="科研共同近期收入比例"></label><div class="budget-comparison">${rows.map((r,i)=>`<article><b>${i?'铀':'铁'}投入 / 游戏秒</b><strong>${i?state.researchUranium:state.researchBudget} → ${r.rate}</strong><span>收入结余 ${r.left} / 秒</span><span>${r.rate==='0'?'停用付费加速':'无后续收入时库存可付 '+r.reserve+' 秒'}</span></article>`).join('')}</div><p>本级完成：${({equipment_finishing:'武器与防御普通值 ×1.25',uranium_extraction:'原生铀收入 ×1.1',weapon_accuracy:'武器伤害 ×1.1',equipment_reinforcement:'防御普通容量 ×1.1',resource_refining:'原生铁收入 ×1.1',singularity:'AI数量 +1',fragment_condensation:'直接碎片收入 ×1.1',unification:'联合因子按完成时收入峰值更新'})[state.researchId]}。投入改变用时，完成收益保持。</p><p>当前研究速度 ${studies[state.researchId].speed} · 预计${studies[state.researchId].remaining}；目标速度与时间待预览。</p><div class="secondary-actions">${control('research-intent-now','生成即时投入草稿')}${control('research-intent-auto','保持此收入比例','primary')}</div><small>即时草稿按当前收入样本换算；持续预算每60游戏秒重算。0%即时草稿为0；持续预算开启时每种资源至少投入1 / 秒。</small></div>`;
}
function research() {
  const study=studies[state.researchId];
  const stopped=state.paused||state.researchState==='paused'||state.researchState==='completed';
  const status=state.researchState==='completed'?'本级研究完成':state.paused||state.researchState==='paused'?'暂停':state.researchState==='unfunded'?'基础研究中 · 投入加速不足':'研究中';
  const dirty=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium;
  return moduleHead('AI科技工厂 · '+study.name,'Lv.'+study.level+' · '+study.effect,`<span class="pill ${stopped?'warn':'good'}">${status}</span>`)+
    `<div class="factory-room ${stopped?'stopped':'working'}"><img class="factory-background" src="${asset}ai_tech_factory/workshop-background-v2.png" alt="AI工厂场景"><img class="factory-machine" src="${asset}ai_tech_factory/${study.image}" alt="${study.name}设备"><img class="factory-probe" src="${asset}ai_tech_factory/inspection-probe-v2.png" alt="当前研究探针"><div class="research-device-status"><span class="eyebrow">CURRENT DEVICE</span><b>${study.name}</b><span>${state.researchState==='completed'?'100%':study.progress}</span><div class="meter"><i style="width:${state.researchState==='completed'?'100%':study.progress}"></i></div><small>工作量 ${state.researchState==='completed'?study.required:study.work} / ${study.required}</small><small>速度 ${study.speed}工作量 / 游戏秒</small><small>${state.researchState==='completed'?'已完成，等待选择下一研究':stopped?'暂停期间不推进':'预计剩余 '+study.remaining+'（游戏时间）'}</small></div><button data-action="research-select" class="factory-selector">选择研究设备</button></div>`+
    `<div class="investment-console">${researchIntentPanel()}<div class="investment-title"><div><h3>投入控制台</h3><small>${dirty?'草稿未应用，当前生效值保持':'当前投入已生效'}</small></div>${control('research-reset','还原当前值','quiet')}</div><div class="investment-row"><div class="investment-resource"><label>铁 / 游戏秒<input id="research-budget" value="${escapeText(state.researchDraft)}"></label><span>当前 <b>${escapeText(state.researchBudget)}</b></span>${control('research-apply-iron','应用铁投入','primary')}</div><div class="investment-resource"><label>铀 / 游戏秒<input id="research-uranium" value="${escapeText(state.researchUraniumDraft)}"></label><span>当前 <b>${escapeText(state.researchUranium)}</b></span>${control('research-apply-uranium','应用铀投入','primary')}</div></div>${state.researchError?`<div class="note bad">${state.researchError}</div>`:''}${state.researchFeedback?`<div class="research-feedback">${state.researchFeedback}</div>`:''}<div class="research-automation"><div><label><input type="checkbox" id="research-auto-toggle" ${state.researchAutoDraft?'checked':''}> 自动投入预算</label><label>比例 <input id="research-ratio" type="number" min="0" max="100" step="any" value="${state.researchRatioDraft}">%</label>${control('research-auto-apply','应用预算设置')}<small>当前${state.researchAuto?'开启':'关闭'} · ${state.researchRatio}% · 下个60游戏秒预算刷新点采用</small></div><div><b>岗位自动续研</b><span>${crewCount('research')?'已有人 · 完成后续研最短项目':'当前无人 · 完成后停下'}</span>${control('research-crew','查看科研岗位','quiet')}</div></div></div>`+
    (state.researchDrawer?`<div class="research-drawer"><div class="drawer-head"><div><h2>选择当前研究设备</h2><span>切换保留每项已完成工作量</span></div>${control('research-close','关闭')}</div><div class="study-grid">${state.researchUnlocked.map(id=>{const item=studies[id];return `<button data-study="${id}" class="study-option ${state.researchId===id?'selected':''}"><img src="${asset}ai_tech_factory/${item.image}" alt=""><b>${item.name}</b><span>Lv.${item.level} · ${item.progress}</span><small>${item.effect}</small></button>`;}).join('')}</div></div>`:'');
}

function enhancement(){
 const e=state.enhance,models=EnhancementModels,q=models.quotes[e.purchaseMode];
 const branchRoute=state.route.startsWith('enhancement/branch/'),effect=models.effects[e.effect],group=e.weapon.includes(e.effect)?e.weapon:e.defence,position=group.indexOf(e.effect),gates=models.positions[position];
 const current=e.branches[e.effect][e.node],gate=gates.nodeGates[e.node],unlocked=e.effective>=gate,disabledB=e.effect==='repeat'&&e.node===1;
 return moduleHead('全局强化','武器与防御共用有效等级，费用按购买等级',`<span class="pill">碎片 ${e.funds?(e.quoteUsed?e.balance:"64.0 B"):"2.1 K"}</span>`)+`<div class="enhancement-levels"><div><small>购买等级</small><b>${e.paid}</b></div><span>＋</span><div><small>世界额外</small><b>${e.extra}</b></div><span>＝</span><div class="effective"><small>有效等级</small><b>${e.effective}</b></div><div class="enhancement-buy"><div>${control('enhance-one','购买1级',e.purchaseMode==='one'?'active':'')}${control('enhance-ten','最多购买10级',e.purchaseMode==='ten'?'active':'')}</div><span>本次可购${q.count}级 · 合计 ${q.price}碎片</span>${control('enhance-buy','确认购级','primary',!e.funds||e.quoteUsed)}</div></div>${!e.funds?'<div class="enhance-inline-error">碎片不足；当前报价和等级保留。</div>':''}${e.feedback?`<div class="note">${e.feedback}</div>`:''}<div class="enhance-groups">${[['weapon','武器作用顺序'],['defence','防御作用顺序']].map(([key,title])=>`<section class="enhance-chain"><h3>${title}</h3>${e[key].map((id,i)=>{const m=models.effects[id],p=models.positions[i];return `<article class="enhance-effect"><div class="enhance-effect-identity"><span class="effect-symbol">${m.symbol}</span><div><small>顺位 ${i+1} · 有效等级${p.effectGate}开放</small><h2>${m.name}</h2></div>${control('enhance-move-'+id,'前移','quiet')}</div><p>${e.quoteUsed?({repeat:{31:"50%触发0.5秒后额外攻击；本级伤害 ×7.2",32:"50%触发0.5秒后额外攻击；本级伤害 ×7.4"},memory:{31:"每0.2秒修复最大值的31%；满后充能保护",32:"每0.2秒修复最大值的32%；满后充能保护"}})[id]?.[e.effective]||m.summary:m.summary}</p><div class="enhance-nodes">${p.nodeGates.map((g,j)=>`<button data-enhance-node="${id}:${j}" class="${e.effective>=g?'open':'locked'}"><small>节点${j+1} · E${g}</small><b>${e.branches[id][j]||'未选'}</b><span>${e.effective<g?(e.branches[id][j]?'保留选择 · 暂停生效':'未开放'):id==='repeat'&&j===1&&e.branches[id][j]==='B'?'B保留 · 功能不启用':e.branches[id][j]?'当前已生效':'可选择'}</span></button>`).join('')}</div></article>`;}).join('')}</section>`).join('')}</div>${branchRoute?`<div class="branch-sheet"><div class="drawer-head"><div><span class="eyebrow">${effect.name} / NODE ${e.node+1}</span><h2>节点${e.node+1} · 有效等级${gate}</h2><span>当前路径 ${e.branches[e.effect].map(x=>x||'—').join(' → ')} · 当前E${e.effective}</span></div>${control('back','返回强化')}</div>${!unlocked?'<div class="note warn">门槛未满足；原选择保留并暂不生效。</div>':''}<div class="branch-options">${['A','B'].map(c=>`<button data-enhance-choice="${c}" class="${e.choice===c?'selected':''}" ${!unlocked||c==='B'&&disabledB?'disabled':''}><b>路径 ${c} ${current===c?'· 当前选择':''}</b><p>${c==='A'?effect.a:effect.b[e.node]}</p>${c==='B'&&disabledB?'<small>现行规则禁用；已存选择不删除。</small>':''}</button>`).join('')}</div><div class="branch-confirm"><span>${e.choice?'候选 '+e.choice+' · 当前选择仍为 '+(current||'未选'):'选择后比较，再确认应用'}</span>${control('enhance-branch-apply','确认分支','primary',!unlocked||!e.choice||e.choice===current)}</div></div>`:''}`;
}
function crew() {
  const member=state.crewMembers[state.crewId], error=crewAdmission(), planetJob=state.crewDraft.startsWith('planet-');
  const available=Object.entries(state.crewMembers).filter(([id,m])=>m.available);
  const target=state.planets.find(p=>p.id===state.crewPlanet);
  return moduleHead('船员名册 · '+available.length+'人可用','人物身份与当前岗位分别显示',`<span class="pill">${member.name} · Lv.${member.level}</span>`)+
    `<div class="crew-room"><div class="crew-roster">${available.map(([id,m])=>`<button data-crew="${id}" class="crew-person ${state.crewId===id?'selected':''}"><span class="job-badge">${m.job==='idle'?'◇':m.job==='planet-build'?'⚒':m.job==='planet-explore'?'◎':'◈'}</span><span><b>${m.name}</b><small>Lv.${m.level} · ${memberJob(m)}</small></span><div class="meter"><i style="width:${m.experienceRatio*100}%"></i></div></button>`).join('')}<div class="crew-next">下位船员：${Object.values(state.crewMembers).find(m=>!m.available)?.name} · 通关45关开放</div></div><div class="person-console"><div class="person-heading"><span class="job-badge large">${member.job==='idle'?'◇':'◈'}</span><div><span class="eyebrow">CREW / CURRENT ASSIGNMENT</span><h2>${member.name}</h2><span>Lv.${member.level} · 经验 ${member.experience} / ${member.experienceRequired}</span></div></div><div class="meter"><i style="width:${member.experienceRatio*100}%"></i></div><div class="current-job"><small>当前实际占用</small><b>${memberJob(member)}</b><span>${({research:'科研速度 ×1.6；完成后自动续研最短项目',equipment:'装备属性 ×1.331；每秒尝试全部启用槽位正常付费购级',reactor:'反应炉总能源 ×1.9；每秒尝试购级并均分',enhancement:'直接碎片 ×1.3；每秒尝试购1级全局强化',idle:'当前无岗位占用'})[member.job]||'当前任务按探索或工程完成提供经验；不计为系统岗位等级加成'}</span>${member.job==='planet-build'?'<span>本次探索完成时检查施工人员，达到次数后释放施工占用。</span>':member.job==='research'?'<span>完成后续研最短项目；当前研究设备保持。</span>':''}</div><div class="dispatch-draft"><h3>派遣候选</h3><label>岗位<select id="crew-target">${Object.entries(jobs).filter(([id])=>id!=='hyperspace').map(([id,name])=>`<option value="${id}" ${id===state.crewDraft?'selected':''}>${name}</option>`).join('')}</select></label>${planetJob?`<label>星球<select id="crew-planet">${state.planets.filter(p=>p.available).map(p=>`<option value="${p.id}" ${p.id===target.id?'selected':''}>${p.name}</option>`).join('')}</select></label>${state.crewDraft==='planet-build'?`<label>施工设施<select id="crew-facility">${Object.values(target.facilities).map(f=>`<option value="${f.id}" ${f.id===state.crewFacility?'selected':''}>${f.name} · 额外人员${f.extraCrew}</option>`).join('')}</select></label>`:''}`:''}${state.crewDraft==='equipment'?`<label>自动购级模式<select id="crew-mode">${['1','10','MAX'].map(v=>`<option ${v===state.crewMode?'selected':''}>${v}</option>`).join('')}</select></label>`:''}<div class="note ${error?'warn':''}">${error||'确认后切换目标；当前实际占用保持至接纳成功。'}</div>${state.crewError?`<div class="note bad">${state.crewError}</div>`:''}<div class="secondary-actions">${control('crew-apply','确认派遣','primary',!!error)}${control('crew-release','释放当前占用','',member.job==='idle'||member.job==='hyperspace')}${control('crew-target','查看候选目标')}${control('back','返回来处','quiet')}</div></div></div></div>`;
}
function routeName(id=state.routeId) {return {pulse:'脉冲路线',missile:'导弹路线',rail:'舰炮路线',beam:'长激光路线'}[id];}
function taskStatus(task){return {idle:'待命',running:'进行中',ready:'待领取',claimed:'已领取'}[task.status];}
const hyperTabs=[['routes','路线任务'],['warehouse','仓库'],['formation','无人机编队'],['forge','改造'],['filter','过滤'],['materials','材料']];
function hyperNav() {return `<div class="subnav">${hyperTabs.map(([id,name])=>`<button data-route="hyperspace/${id}" class="${state.route==='hyperspace/'+id?'active':''}">${name}</button>`).join('')}</div>`;}
function droneStrip() {
  return `<div class="drone-strip"><span>当前对象</span>${Object.entries(drones).map(([id,d])=>`<button data-drone="${id}" class="${state.droneId===id?'active':''}">${d.name}</button>`).join('')}</div>`;
}
function droneNameList(ids) {return ids.length?ids.map(id=>drones[id].name).join(' / '):'无';}
function taskPanel(kind) {
  const task=kind==='manual'?state.manualTask:state.onlineTask;
  const label=kind==='manual'?'手动挑战':'在线挂机';
  return `<article class="task-panel"><div><span class="eyebrow">${kind==='manual'?'MANUAL RUN':'ONLINE RUN'}</span><h2>${label}</h2><span class="pill ${task.status==='ready'?'warn':''}">${taskStatus(task)}</span></div><p><b>${routeName(task.route)}</b> · 第${kind==='manual'?'19':'18'}层<br>任务 ${task.run}<br>${kind==='online'?'模式 '+(task.mode==='auto'?'自动挂机':'单次挂机')+' · '+(task.crewId?state.crewMembers[task.crewId].name:'无保留船员'):'挑战胜利后才有成功回执'}</p><div class="secondary-actions">${kind==='manual'?control('hyper-manual',task.status==='running'?'查看当前挑战':'查看挑战条件','primary'):control('online-start',task.status==='running'?'单次进行中':'开始单次挂机','primary',task.status==='running'||task.status==='ready')}${control('receipt-'+kind,'查看本任务回执')}${task.status==='ready'?control('claim-'+kind,'领取此回执'):''}${kind==='online'?control('online-auto',task.status==='running'&&task.mode==='auto'?'停止自动挂机':'开始自动挂机','',task.status==='running'&&task.mode!=='auto'):''}</div></article>`;
}
function taskReceipt(kind) {
  const task=kind==='manual'?state.manualTask:state.onlineTask;
  return `<div class="receipt"><span class="eyebrow">${kind==='manual'?'MANUAL RECEIPT':'ONLINE RECEIPT'}</span><h2>${kind==='manual'?'手动':'在线'} · ${routeName(task.route)} · ${task.run}</h2><p>任务状态：${taskStatus(task)}<br>对象与回执在任务开始时绑定，当前浏览路线不会替换它。<br>${task.status==='ready'?'奖励已在完成时固化，领取不重新抽取。':task.status==='claimed'?'本回执已领取，不可重复入账。':'尚无可领取奖励。'}</p>${control('claim-'+kind,'领取此回执','primary',task.status!=='ready')}${control('back','返回来处')}</div>`;
}

function hyperspace() {
  const part=state.route.split('/')[1]||'routes', d=drones[state.droneId];
  let body='';
  if(part==='routes') body=`<div class="route-grid">${Object.entries({pulse:'脉冲',missile:'导弹',rail:'舰炮',beam:'长激光'}).map(([id,name])=>`<button class="route-card ${state.routeId===id?'selected':''}" data-hyper-route="${id}"><img src="${asset}hyperspace/icons/${id}.png" alt=""><b>${name}路线</b><span>已通过18 · 下一挑战19</span></button>`).join('')}</div><div class="browse-route">正在浏览 ${routeName()} · 能源240 · 三种模式门票均为0</div><div class="task-panels">${taskPanel('manual')}${taskPanel('online')}</div>`;
  if(part==='warehouse') body=`<div class="warehouse-heading"><span>主仓 3 / 40</span><span>溢出0 · 封存0</span><span>已选 ${state.droneSelection.length}</span></div><div class="drone-grid">${Object.entries(drones).map(([id,item])=>`<article class="drone-card ${state.droneId===id?'selected':''}"><img src="${asset}hyperspace/icons/${item.icon}" alt=""><h3>${item.name}</h3><p>${item.quality} · Lv.${item.level}<br>${item.affix}</p><span class="pill">${state.equippedDrones.includes(id)?'已装备':'主仓'}</span><div>${control('drone-pick-'+id,state.droneSelection.includes(id)?'取消选中':'选中')}${control('drone-detail-'+id,'详情')}</div></article>`).join('')}</div><div class="secondary-actions">${control('warehouse-formation','以所选无人机编队','primary',!state.droneSelection.length)}${control('warehouse-forge','改造所选对象','',state.droneSelection.length!==1)}${control('warehouse-filter','过滤规则')}${control('warehouse-sealed','封存 / 整理')}</div>`;
  if(part==='drone') body=`${droneStrip()}<div class="drone-detail"><img src="${asset}hyperspace/icons/${d.icon}" alt=""><div><h2>${d.name}</h2><p>${d.quality} · Lv.${d.level} · ${d.weapon}</p><p>当前词缀 ${d.affix}</p><span class="pill">${state.equippedDrones.includes(state.droneId)?'当前已装备':'主仓可选'}</span></div></div><div class="secondary-actions">${control('drone-to-formation','进入无人机编队','primary')}${control('drone-to-forge','进入改造')}${control('drone-hanging','挂设与成长')}${control('drone-favorite','收藏 / 保护')}${control('back','返回仓库','quiet')}</div>`;
  if(part==='formation') body=`${droneStrip()}<div class="formation-stage"><div class="formation-mother"><img src="${asset}ui/ships/fleet_20261019/03-cruiser.png" alt="母舰预览"><span>巡洋舰 · 容量3</span></div><div class="formation-slots">${[0,1,2].map(i=>`<div class="formation-slot"><small>无人机位 ${i+1}</small><b>${state.formationDraft[i]?drones[state.formationDraft[i]].name:'空位'}</b></div>`).join('')}</div></div><div class="formation-compare"><div><small>当前编队</small><b>${droneNameList(state.equippedDrones)}</b></div><div><small>本次候选</small><b>${droneNameList(state.formationDraft)}</b></div></div>${state.formationPreview?`<div class="transaction-preview"><b>应用前装卸确认</b><p>将装备：${droneNameList(state.formationPreview.equip)}<br>将卸下：${droneNameList(state.formationPreview.remove)}</p>${control('formation-confirm','确认应用','primary')}${control('formation-cancel','取消')}</div>`:''}<div class="secondary-actions">${control('formation-set','将当前对象放入候选')}${control('formation-preview','查看本次装卸','primary')}${control('back','返回来处','quiet')}</div>`;
  if(part==='forge') body=`${droneStrip()}<div class="forge-layout"><div class="forge-original"><img src="${asset}hyperspace/icons/${d.icon}" alt=""><h2>${d.name}</h2><p>原词缀 ${d.affix}</p><span class="pill">${d.quality} / 已收藏保护独立</span></div><div class="forge-choice"><label>本次操作 <select id="forge-operation"><option value="reroll" ${state.forgeOperation==='reroll'?'selected':''}>重掷普通词缀</option><option value="refine" ${state.forgeOperation==='refine'?'selected':''}>精炼当前词缀</option></select></label><p>支付材料 20 · 保留装备身份与保护项</p>${state.forgePreview?`<div class="transaction-preview"><h3>${d.name} · 本次预览</h3><p>变化范围：攻击 +6%～12%<br>随机结果尚未取得；保护项不变。</p>${control('forge-confirm','确认支付并改造','primary')}${control('forge-cancel','取消预览')}</div>`:control('forge-preview','预览变化与代价','primary')}${state.forgeResult?`<div class="receipt"><b>实际结果 · ${drones[state.forgeResult.id].name}</b><p>${state.forgeResult.before} → ${state.forgeResult.after}<br>实际支付 材料20</p></div>`:''}</div></div><div class="secondary-actions">${control('back','返回来处','quiet')}</div>`;
  if(part==='filter') body=`<div class="filter-editor"><h2>当前过滤规则</h2><div class="current-job">当前生效：${state.filter.quality} → ${state.filter.action}</div><div class="form-row"><label>匹配品质 <select id="filter-quality">${['稀有以下','普通','史诗以下'].map(v=>`<option ${state.filterDraft.quality===v?'selected':''}>${v}</option>`).join('')}</select></label><label>处理动作 <select id="filter-action">${['保留','拆解'].map(v=>`<option ${state.filterDraft.action===v?'selected':''}>${v}</option>`).join('')}</select></label></div><p>规则导入先审阅，非法输入不替换当前规则。</p><textarea id="filter-source" placeholder="粘贴规则文本">${escapeText(state.importFilterText||'')}</textarea><div class="secondary-actions">${control('filter-apply','应用规则','primary')}${control('filter-import','审阅导入')}${control('filter-export','导出当前规则')}${control('back','返回来处','quiet')}</div></div>`;
  if(part==='materials') body=`<div class="materials"><h2>材料兑换</h2><div class="metrics"><span>源材料余额<b>240</b></span><span>目标材料余额<b>60</b></span></div><label>源材料支付量 <input id="material-amount" readonly value="100"></label><div class="note">本次支付100源材料 → 收到20目标材料</div>${control('materials-exchange','确认兑换','primary')}${state.materialReceipt?`<div class="receipt">${state.materialReceipt}</div>`:''}${control('back','返回来处','quiet')}</div>`;
  if(['sealed','hanging','protection','receipt','manual','filter-import','filter-export'].includes(part)) body=hyperSubroute(part);
  return moduleHead('超空间 · '+(hyperTabs.find(row=>row[0]===part)?.[1]||{drone:'无人机详情',sealed:'仓储处理',hanging:'挂设成长',protection:'收藏保护',receipt:'本次回执',manual:'手动挑战','filter-import':'审阅规则导入','filter-export':'导出规则'}[part]),`浏览 ${routeName()} · 当前无人机 ${d.name}`)+hyperNav()+body;
}
function hyperSubroute(part) {
  const d=drones[state.droneId];
  if(part==='receipt') return taskReceipt(state.route.split('/')[2]==='online'?'online':'manual');
  if(part==='manual') {const task=state.manualTask;return `<div class="transaction-preview"><h2>${task.status==='running'?routeName(task.route):routeName()} · 手动挑战</h2><p>${task.status==='running'?'任务'+task.run+'进行中，不能用当前浏览路线替换任务对象。':'下一挑战19层 · 门票0 · 查看此页尚未开始。'}<br>在线任务 ${routeName(state.onlineTask.route)} / ${taskStatus(state.onlineTask)} 保持独立。</p>${control('manual-start','确认开始挑战','primary',task.status==='running'||task.status==='ready')}${control('receipt-manual','手动回执')}${control('back','返回来处')}</div>`;}

  if(part==='filter-import') return `<div class="transaction-preview"><h2>规则导入审阅</h2><p>原规则：${state.filter.quality} → ${state.filter.action}</p><pre>${escapeText(state.importFilterText||'空规则：无法应用')}</pre>${control('filter-import-confirm','确认替换','primary',!state.importFilterValid)}${control('back','取消，保留原规则')}</div>`;
  if(part==='filter-export') return `<div class="receipt"><h2>当前规则文本</h2><textarea readonly>${escapeText(JSON.stringify(state.filter))}</textarea>${control('back','返回规则')}</div>`;
  return `${droneStrip()}<div class="detail-route"><h2>${d.name} · ${{sealed:'仓储与封存',hanging:'挂设与成长',protection:'收藏与保护'}[part]}</h2><div class="current-job">当前对象 ${state.droneId} / ${d.quality} / ${d.weapon}</div><p>${part==='sealed'?'主仓、溢出和封存分开；当前封存为空，整理不会修改选中的无人机。':part==='hanging'?'当前挂设：无。候选挂设与已生效值分别查看，限制与费用在确认前显示。':'收藏、传说收藏和过滤保护分别标记；受保护对象不可从此绕过拆解限制。'}</p>${control('back','返回原工作点','primary')}</div>`;
}
function settings() {
  if(state.route.includes('/danger/')) return danger();
  const m=state.maintenance,save=MaintenanceModels.saveStates[m.save];
  const tabs=`<div class="subnav">${[['save','保存与恢复'],['preferences','音画与自动保存'],['danger/reforge','重铸'],['danger/import','导入'],['danger/new','新游戏']].map(([id,name])=>`<button data-route="settings/${id}" class="${state.route==='settings/'+id?'active':''}">${name}</button>`).join('')}</div>`;
  if(state.route==='settings/preferences')return moduleHead('音画与自动保存','当前个人设置与可修改值')+tabs+`<div class="preferences-grid"><section><h2>声音与表现</h2><label><input id="pref-music" type="checkbox" ${m.music?'checked':''}>音乐 ${m.music?'开启':'关闭'}</label><label><input id="pref-effects" type="checkbox" ${m.effects?'checked':''}>音效 ${m.effects?'开启':'关闭'}</label><label>伤害数字<select id="pref-damage">${[['all','全部'],['critical','仅暴击'],['off','关闭']].map(([v,t])=>`<option value="${v}" ${m.damage===v?'selected':''}>${t}</option>`).join('')}</select></label></section><section><h2>保存与引导</h2><label>自动保存间隔<input id="pref-interval" type="number" min="0" max="86400" value="${m.interval}">现实秒</label><small>0为关闭；暂停不阻止保存，不推进游戏时间。</small><label><input id="pref-skip" type="checkbox" ${m.skip?'checked':''}>自动跳过引导提示</label>${control('archive-tutorial','主动回看飞行手册','quiet')}</section></div><div class="note">${m.feedback||'当前设置已显示；修改失败时保留原值并显示原因。'}</div>`;
  return moduleHead('保存与恢复','当前目录与实际持久化状态')+tabs+`<div class="save-dashboard ${m.save}"><span class="eyebrow">PERSISTENCE / CURRENT STORE</span><h2>${save.title}</h2><p>${save.description}</p><div class="save-timeline"><span>请求${['queued','writing','saved'].includes(m.save)?' ●':' ○'}</span><i></i><span>写盘${['writing','saved'].includes(m.save)?' ●':' ○'}</span><i></i><span>已持久化${m.save==='saved'?' ●':' ○'}</span></div><label>当前目录 <b>${escapeText(m.directory)}</b></label><label>候选目录 <input id="save-directory" value="${escapeText(m.directoryDraft)}"></label><div class="secondary-actions">${control('save-directory-apply','使用候选目录')}${control('save-picker','选择目录')}${control('save-retry','请求保存','primary',['queued','writing'].includes(m.save))}${control('save-backup','有效备份 / 恢复')}${control('danger-import','导入存档')}</div>${m.feedback?`<div class="note">${escapeText(m.feedback)}</div>`:''}</div><div class="maintenance-summary"><article><h3>个人设置</h3><p>音乐${m.music?'开启':'关闭'} · 音效${m.effects?'开启':'关闭'} · 自动保存${m.interval}现实秒</p>${control('settings-audio','声音与显示')}</article><article><h3>危险事务</h3><p>重铸、导入、新游戏分别预览当前对象。</p>${control('danger-reforge','重铸')}${control('danger-new','新游戏')}</article></div>`;
}
function danger() {
 const kind=state.route.split('/')[2]||'reforge',m=state.maintenance;state.dangerKind=kind;
 const title={reforge:'重铸',import:'导入存档',new:'新游戏'}[kind],preview=state.dangerPreview?.kind===kind?state.dangerPreview:null;
 const source=kind==='reforge'?selectedPlanet().name:kind==='import'?m.importSource:m.newDirectory;state.dangerSource=source;
 const allowed=kind!=='reforge'||Object.values(selectedPlanet().facilities).some(f=>f.type==='shipyard'&&f.state==='owned');
 const matrix=MaintenanceModels.reforge;
 return moduleHead(title,'选择、预览、确认与实际结果分开')+`<div class="danger-route"><div class="transaction-source"><h2>本次${title}对象</h2>${kind==='reforge'?`<label>星球<select id="danger-planet">${state.planets.filter(p=>p.available).map(p=>`<option value="${p.id}" ${p.id===state.planetId?'selected':''}>${p.name}</option>`).join('')}</select></label><p>保留无人机（候选）</p><div class="retained-drones">${Object.entries(drones).map(([id,d])=>`<label><input type="checkbox" data-retain-drone="${id}" ${m.retained.includes(id)?'checked':''}>${d.name}</label>`).join('')}</div>${allowed?'':'<div class="note warn">所选星球船坞尚未领取，当前不能重铸；可先查看重置范围。</div>'}`:kind==='import'?`<label>来源文件<input id="import-source" value="${escapeText(m.importSource)}"></label><p>候选校验通过后才能替换当前会话；不兼容文件原样保留。</p>`:`<label>新档目录<input id="new-directory" value="${escapeText(m.newDirectory)}"></label><label><input id="new-clear-settings" type="checkbox" ${m.clearSettings?'checked':''}>同时重置个人设置</label><p>建立独立新航程，原有效档或损坏文件不会因查看而覆盖。</p>`}${m.dangerError?`<div class="note bad">${escapeText(m.dangerError)}</div>`:''}${control('danger-preview','生成本次预览','primary',!allowed)}</div>${preview?`<div class="transaction-preview"><span class="eyebrow">REVIEW / ${preview.id}</span><h2>${title} · ${escapeText(preview.source)}</h2><div class="loss-grid"><div><b>清除 / 替换</b><ul>${(kind==='reforge'?matrix.clear:kind==='import'?['当前内存会话替换为此候选会话','当前临时战斗重建；手动Started任务按中断处理']:['当前航程切换至新档初始进度',preview.clearSettings?'个人设置重置':'个人设置保留']).map(t=>`<li>${t}</li>`).join('')}</ul></div><div><b>保留 / 收益</b><ul>${(kind==='reforge'?[...matrix.keep,...(selectedPlanet().id==='1'?matrix.gain:['本星球标记征服：装备有效等级+15、免费充能+10%、强化有效等级+1、幸运+100','保留无人机封存至所属星球门槛；仓库/保留容量各+10','新起点第'+({'2':10,'3':15,'4':20,'5':25,'6':30})[selectedPlanet().id]+'关；建立全新战场']), '指定保留：'+droneNameList(preview.retained)]:kind==='import'?['候选摘要：第40关 · '+preview.source,'在线剩余任务与待领回执按来源恢复','内存替换与写盘结果分别报告']:['目标目录：'+preview.source,'原文件保留；新航程单独持久化']).map(t=>`<li>${escapeText(t)}</li>`).join('')}</ul></div></div>${control('danger-confirm','确认本次'+title,'primary')}${control('danger-cancel','取消预览')}</div>`:'<div class="empty-preview">修改对象、来源或保留选择后需重新预览。</div>'}${state.dangerResult?`<div class="receipt"><b>${escapeText(state.dangerResult)}</b></div>`:''}<div class="secondary-actions">${control('back','返回原工作点','quiet')}</div></div>`;
}
function archive(){
 const a=state.archive,tab=state.route.split('/')[1]||a.tab;a.tab=tab;
 const tabs=[['tutorial','飞行手册'],['intel','当前敌情'],['notifications','通知档案'],['statistics','伤害明细']];
 let body='';
 if(tab==='tutorial'){const help=MaintenanceModels.tutorials[a.tutorial];body=`<div class="archive-split"><div class="archive-index">${Object.entries(MaintenanceModels.tutorials).map(([id,t])=>`<button data-tutorial="${id}" class="${id===a.tutorial?'active':''}"><b>${t[0]}</b><span>${a.completed.includes(id)?'已实践':'可回看'}</span></button>`).join('')}</div><article class="archive-paper"><span class="eyebrow">FLIGHT MANUAL / ${a.tutorial.toUpperCase()}</span><h2>${help[0]}</h2><div class="manual-diagram">${({equip:['选中槽位','比较候选','确认换装'],upgrade:['选择数量','查看总费用','购级结果'],pickup:['资源出现','点击或等待','实际入账'],retreat:['防御耗尽','撤退航行','恢复后出击'],clear:['终波清空','结算奖励','查看解锁']})[a.tutorial].map((x,i)=>(i?'<i>→</i>':'')+'<span>'+x+'</span>').join('')}</div><p>${help[1]}</p><div class="secondary-actions">${control('tutorial-target','前往对应工作点','primary')}${a.guidePaused?control('tutorial-continue','继续航行'):''}</div><small>${a.guidePaused?'当前为首次引导暂停；继续仅释放引导暂停。':'主动回看不暂停航程，也不会重置已完成记录。'}</small></article></div>`;}
 if(tab==='intel'){const n=a.intel.find(x=>x.id===a.enemy);body=`<div class="archive-split"><div class="archive-index">${a.intel.map(n=>`<button data-intel="${n.id}" class="${a.enemy===n.id?'active':''}">${n.name}<span>${n.tier}</span></button>`).join('')}</div><article class="intel-paper"><img src="${asset}ui/ships/fleet_20261019/${n.image}" alt="${n.name}当前视觉来源"><div><span class="eyebrow">CURRENT ENEMY</span><h2>${n.name}</h2><span class="pill">${n.tier}</span><dl><dt>装甲</dt><dd>${n.armour}</dd><dt>护盾</dt><dd>${n.shield}</dd></dl><p>${n.mechanics}</p></div></article></div>`;}
 if(tab==='notifications')body=`<div class="notification-header"><h2>未读 ${a.notifications.filter(n=>!n.read).length}</h2><span>已见与已读分别保留</span></div><div class="notification-list">${a.notifications.map(n=>`<article><div><small>${n.key.split(':')[0]==='unlock'?'开放':'科研'}</small><h3>${n.title}</h3><span>${n.seen?'已见':'未见'} · ${n.read?'已读':'未读'}</span></div><div><button data-notification-seen="${n.key}" ${n.seen?'disabled':''}>${n.seen?'已见':'标记已见'}</button><button data-notification-read="${n.key}" ${n.read?'disabled':''}>${n.read?'已读':'阅读此条'}</button></div></article>`).join('')}</div>`;
 if(tab==='statistics')body=`<div class="statistics-paper"><h2>伤害明细</h2><p>同一统计来源，按护盾与装甲分列。</p><table><thead><tr><th>来源</th><th>总伤害</th><th>护盾</th><th>装甲</th></tr></thead><tbody><tr><td>武器1 · 脉冲</td><td>128.0 K</td><td>44.0 K</td><td>84.0 K</td></tr><tr><td>武器2 · 导弹</td><td>94.0 K</td><td>32.0 K</td><td>62.0 K</td></tr></tbody></table><small>按实际来源累计，数值不随档案页面开关重置。</small></div>`;
 return moduleHead('航行档案','教程、当前敌情与通知主动查阅')+`<div class="subnav">${tabs.map(([id,name])=>`<button data-route="archive/${id}" class="${tab===id?'active':''}">${name}</button>`).join('')}</div>`+body;
}
function catalog() {
  return moduleHead('全系统工作对象','返回所选对象的上次工作位置')+`<div class="system-objects">${modules.map(([id,name,en])=>`<button class="object-card" data-module="${id}" style="text-align:left;white-space:normal;min-height:80px"><span class="eyebrow">${en}</span><h3>${name}</h3></button>`).join('')}</div>`;
}
function dock() {
  if(state.collapsed) return '';
  if(state.module==='equipment') {
    const q=equipmentQuote(), disabled=q.next==='待取得新报价'||state.equipment==='poor'||(q.action==='equip-apply'&&currentCooldown()>0);
    return `<div class="dock-summary"><b>${state.slot<3?'武器槽'+(state.slot+1):'防御槽'+(state.slot-2)} · ${state.fits[state.slot]} Lv.${state.levels[state.slot]}</b><span>${q.label} · ${q.current} → <strong>${q.next}</strong> · ${comparisonCycle()}</span><span>本次费用 <strong>${q.price}</strong></span></div><div class="dock-buttons">${control(q.action,currentCooldown()>0&&q.action==='equip-apply'?'冷却剩余'+currentCooldown()+'游戏秒':q.label,'primary',disabled)}${control('equip-compare',state.candidate?'查看购级':'更换候选')}</div>`;
  }
  if(state.module==='reactor') {
    const before=effectSnapshots[state.actual.join()],after=effectSnapshots[state.alloc.join()];
    return `<div class="dock-summary"><b>整组供能草稿 · ${sum(state.alloc)}/100 · 剩余${100-sum(state.alloc)}</b><span>手动 ${state.actual.join('/')} → ${state.alloc.join('/')} · 免费供能保持</span><span>攻击 ${before?.attack||'待读数'} → ${after?.attack||'待效果预览'} / 熔炼 ${before?.income||'待读数'} → ${after?.income||'待效果预览'} · 费用0</span></div><div class="dock-buttons">${control('reactor-apply','确认整组调配','primary',!changed()||sum(state.alloc)>100)}${control('reactor-reset','还原')}</div>`;
  }

  if(state.module==='planet') {const p=selectedPlanet(),f=selectedFacility();return `<div class="dock-summary"><b>${p.name} · ${f.name}</b><span>${facilityStatus(p,f)} · ${f.work}/${f.required}次</span><span>${f.state==='ready'?'领取后本设施收益生效':f.effectSummary}</span></div><div class="dock-buttons">${f.state==='ready'?control('planet-claim','领取此设施收益','primary'):control('planet-crew',f.extraCrew?'调整额外施工人员':'查看探索人员','primary',f.state==='locked'||f.state==='owned')}</div>`;}
  if(state.module==='galaxy'){const n=state.galaxyNodes[state.galaxyNode];return `<div class="dock-summary"><b>第一星系 · ${n.state==='fog'?'未探索节点':n.name}</b><span>${galaxyStatus[n.state][0]} · ${n.progress}%</span><span>工程人员 ${crewCount('galaxy')}/6 · 完成自动生效</span></div><div class="dock-buttons">${control('galaxy-crew','调整星系人员','primary')}</div>`;}
  return '';
}
function render() {
  if(renderedRoute===state.route && !renderedCollapsed && !state.collapsed) rememberScroll();
  document.body.classList.toggle('work-family',state.family==='work');
  document.body.classList.toggle('collapsed',state.collapsed);
  document.querySelectorAll('[data-family]').forEach(button=>button.classList.toggle('active',button.dataset.family===state.family));
  $('#nav').innerHTML=nav(); $('#collapse').textContent=state.collapsed?'展开工作区':'收起工作区'; $('#pause').textContent=state.paused?'▶ 继续':'Ⅱ 暂停';
  let body=state.module==='catalog'?catalog():({reactor,equipment,planet,galaxy,research,crew,enhancement,hyperspace,settings,archive}[state.module]||catalog)();
  if(state.collapsed) body=`<div class="resting"><div class="rest-icon">◈</div><h1>远航仍在继续</h1><p>当前对象与草稿保持。</p>${control('expand','继续当前工作','primary')}</div>`;
  else if(state.family==='work'&&state.module!=='catalog') body=workWrapper(body);
  $('#work-content').innerHTML=body;
  $('#action-dock')?.remove();
  const actions=dock();
  if(actions) {const element=document.createElement('div');element.id='action-dock';element.innerHTML=actions;$('#workspace').append(element);}
  $('#notice').textContent=state.notice;
  $('#save-alert')?.remove();if(['failed','recovery'].includes(state.maintenance.save)){const alert=document.createElement('button');alert.id='save-alert';alert.dataset.action='save-open';alert.textContent=MaintenanceModels.saveStates[state.maintenance.save].title+' · 查看与恢复';$('#battle').append(alert);}
  $('#fragments').textContent=state.enhance.funds?(state.enhance.quoteUsed?state.enhance.balance:'64.0 B'):'2.1 K';
  const scroll=state.scroll[state.route];
  if(scroll) {$('#work-content').scrollTop=scroll.outer; if($('.work-sheet')) $('.work-sheet').scrollTop=scroll.inner;}
  renderedRoute=state.route; renderedCollapsed=state.collapsed;
  requestAnimationFrame(renderPipes); fitBattle();
}
function renderPipes() {
  const grid=$('.reactor-room-grid'),svg=$('.reactor-pipes'),core=$('.reactor-core-assembly img');
  if(!grid||!svg||!core) return;
  const origin=grid.getBoundingClientRect(),c=core.getBoundingClientRect();
  const output=SceneModels.reactor.core.power_out;
  const glow=$('.reactor-energy');if(glow){glow.style.left=(c.width*SceneModels.reactor.core.energy[0]/512-glow.offsetWidth/2)+'px';glow.style.top=(c.height*SceneModels.reactor.core.energy[1]/512-glow.offsetHeight/2)+'px';}
  const startX=c.x-origin.x+c.width*output[0]/512,startY=c.y-origin.y+c.height*output[1]/512;
  svg.setAttribute('viewBox',`0 0 ${origin.width} ${origin.height}`);
  svg.innerHTML=[...grid.querySelectorAll('[data-device]')].map(device=>{
    const image=device.querySelector('img').getBoundingClientRect();
    const endX=image.x-origin.x+image.width*Number(device.dataset.portX)/512;
    const endY=image.y-origin.y+image.height*Number(device.dataset.portY)/512;
    const busX=endX<startX?startX-77:startX+77;
    const trunkY=startY+18;
    return `<path d="M${startX} ${startY} V${trunkY} H${busX} V${endY} H${endX}" fill="none" stroke="#a4beb1" stroke-width="11"/><path class="${state.actual[Number(device.dataset.device)]?'power-flow':''}" d="M${startX} ${startY} V${trunkY} H${busX} V${endY} H${endX}" fill="none" stroke="${state.actual[Number(device.dataset.device)]?'#50a197':'#96a89d'}" stroke-width="4"/>`;
  }).join('');
}

function fitBattle() {
  const host=$('#field-host'),s=Math.min(host.clientWidth/572,host.clientHeight/960);
  $('#world').style.transform=`scale(${s})`;
  $('#geometry').textContent=`${innerWidth} × ${innerHeight} · 战场 ${Math.round(572*s)} × ${Math.round(960*s)} · s ${s.toFixed(3)}`;
  renderPipes();
}
function openDetail(title,text) {
  $('#inspect-detail')?.remove();
  const dialog=document.createElement('dialog'); dialog.id='inspect-detail';
  dialog.innerHTML=`<h2>${title}</h2><p>${text}</p><button data-action="close-detail">返回原工作点</button>`;
  document.body.append(dialog);dialog.showModal();
}
function invalidateForge() {state.forgePreview=null;state.forgeResult=null;}
function syncDemoCrewTargets() {
  for(const p of state.planets){if(!crewCount('planet-explore',p.id)){p.running=false;p.automatic=false;p.elapsed='0';p.duration='0';}}
  const p=selectedPlanet(),f=selectedFacility();state.planet=f.state==='building'?(facilityStatus(p,f)==='施工中'?'building':'paused'):f.state;
}
function validAmountDraft(text) {return /^\d+$/.test(text.trim());}
function action(a) {
  if(a.startsWith('reactor-amount-')&&a!=='reactor-amount-apply'){state.reactorEditIndex=Number(a.split('-')[2]);openDetail('设置设备分配目标',`当前手动值 ${state.actual[state.reactorEditIndex]}。<label>目标金额 <input id="reactor-amount-input" value="${state.alloc[state.reactorEditIndex]}"></label><button data-action="reactor-amount-apply" class="primary">保留为分配草稿</button>`);return;}
  else if(a==='reactor-amount-apply'){const value=$('#reactor-amount-input').value;if(validAmountDraft(value)&&Number(value)<=100){state.alloc[state.reactorEditIndex]=Number(value);$('#inspect-detail').close();state.reactorReceipt='';state.reactorIntent='custom';notify('设备目标已保留为草稿，尚未应用');}else{notify('当前演示容量100以内输入整数；实际分配不变');return;}}
  else if(a==='reactor-task') {state.alloc=[60,35,5,0];state.reactorError='';state.reactorReceipt='';state.reactorIntent='custom';notify('调配方案已展开：武器增加15，防御保持，熔炼减少15');}
  else if(a==='reactor-apply') {
    state.reactorError='';state.reactorReceipt='';
    if(sum(state.alloc)>100)state.reactorError='超过手动预算，未应用，原供能保持。';
    else if(state.reactorIntent==='equal'){state.actual=[...state.alloc];state.reactorReceipt='均分命令已接纳：'+state.actual.join('/')+'；免费供能保持，效果读数已更新。';notify(state.reactorReceipt);}
    else {const receipts=[];let next;while((next=reactorNextCommand())){
      if(next.index===state.reactorFailAt){state.reactorError='演示领域拒绝：'+['武器','防御','熔炼','凝聚'][next.index]+'未接纳；已成功项保持，其余草稿可重试。';break;}
      state.actual=next.next;receipts.push(['武器','防御','熔炼','凝聚'][next.index]+' '+next.current+'→'+next.target);
    }state.reactorReceipt=(changed()?'部分接纳：':'调配已接纳：')+(receipts.join('；')||'无成功项')+'。'+(effectSnapshots[state.actual.join()]?'效果读数已更新。':'分配回执已返回，效果读数待取得。');notify(state.reactorReceipt);}
  }
  else if(a==='reactor-reset') {state.alloc=[...state.actual];state.reactorError='';state.reactorReceipt='';}
  else if(a==='reactor-equal') {state.alloc=state.reactor==='opened'?[25,25,25,25]:[34,33,33,0];state.reactorError='';state.reactorReceipt='';state.reactorIntent='equal';notify('均分草稿已准备，确认后调用均分命令；免费供能保持');}
  else if(a==='reactor-clear') {state.alloc=[0,0,0,0];state.reactorError='';state.reactorReceipt='';state.reactorIntent='clear';notify('清零草稿已准备，免费供能保留');}
  else if(a==='equip-compare') {state.candidate=!state.candidate;state.equipmentMode='one';if(state.equipment==='compare')state.equipment='normal';}
  else if(a==='equip-mode') {state.candidate=false;state.equipmentMode=state.equipmentMode==='max'?'one':'max';}
  else if(a==='equip-apply') {state.attributes[state.slot]=equipmentQuote().next;state.fitKeys[state.slot]=candidateType();state.fits[state.slot]=equipmentNames[state.fitKeys[state.slot]];state.cooldowns[state.slot]=10;state.equipment='normal';state.candidate=false;notify('更换成功，当前槽位与比较保留；换装冷却10游戏秒');}
  else if(a==='equip-buy') {const quote=equipmentQuote();if(quote.next==='待取得新报价'||quote.next===quote.current){notify('当前状态尚无新报价，等级与属性保持');return;}state.attributes[state.slot]=quote.next;state.levels[state.slot]+=state.equipmentMode==='max'?4:state.equipmentMode==='ten'?10:1;notify('已购级，当前槽位和操作模式保持');}
  else if(a==='planet-claim') {const f=selectedFacility();if(f.state==='ready'){f.state='owned';state.planet='owned';notify(selectedPlanet().name+' / '+f.name+'已领取，收益生效');}}
  else if(a==='planet-crew'||a==='planet-explorer') {const p=selectedPlanet(),f=selectedFacility();state.crewDraft=a==='planet-explorer'||!f.extraCrew?'planet-explore':'planet-build';state.crewPlanet=p.id;state.crewFacility=f.id;goRoute('crew');return;}
  else if(a==='planet-auto') {const p=selectedPlanet();p.automatic=!p.automatic;notify(p.automatic?'自动探索已开启':'本次探索仍继续，完成后停止');}
  else if(a==='planet-cancel') {openDetail('立即取消 '+selectedPlanet().name+'探索','本次探索进度清零、自动探索关闭并释放探索人员；已完成施工次数及待领设施保留。'+control('planet-cancel-confirm','确认立即取消','danger'));return;}
  else if(a==='planet-cancel-confirm'){const p=selectedPlanet();for(const m of Object.values(state.crewMembers))if(m.job==='planet-explore'&&m.targetPlanet===p.id)m.job='idle';p.running=false;p.elapsed='0';p.duration='0';p.automatic=false;syncDemoCrewTargets();$('#inspect-detail').close();notify('本次探索已取消并释放探索人员；施工次数保留');}
  else if(a==='planet-buff') {state.dangerSource=selectedPlanet().name;goRoute('settings/danger/reforge');return;}
  else if(a==='enhance-one'||a==='enhance-ten'){state.enhance.purchaseMode=a.endsWith('one')?'one':'ten';}
  else if(a==='enhance-buy'){const e=state.enhance;if(e.funds&&!e.quoteUsed){const q=EnhancementModels.quotes[e.purchaseMode];e.paid=q.paid;e.effective=q.effective;e.quoteUsed=true;e.balance=q.balance;e.feedback='本次已购'+q.count+'级，合计'+q.price+'碎片；已保留实际顺位和分支。后续报价待提供方刷新。';}}
  else if(a.startsWith('enhance-move-')){const e=state.enhance,id=a.slice(13),group=e.weapon.includes(id)?e.weapon:e.defence,i=group.indexOf(id),j=i===0?2:i-1;[group[i],group[j]]=[group[j],group[i]];e.feedback=EnhancementModels.effects[id].name+'已前移；顺位门槛已更新，暂不生效的选择仍保留。';}
  else if(a==='enhance-branch-apply'){const e=state.enhance,g=e.weapon.includes(e.effect)?e.weapon:e.defence,gate=EnhancementModels.positions[g.indexOf(e.effect)].nodeGates[e.node];if(e.effective>=gate&&e.choice&&!(e.effect==='repeat'&&e.node===1&&e.choice==='B')){e.branches[e.effect][e.node]=e.choice;e.feedback=EnhancementModels.effects[e.effect].name+'节点'+(e.node+1)+'已选择'+e.choice+'。';goRoute('enhancement');return;}}
  else if(a==='galaxy-zoom-in'||a==='galaxy-zoom-out'){state.galaxyView.zoom=Math.max(.65,Math.min(2,state.galaxyView.zoom+(a.endsWith('in')?.15:-.15)));}
  else if(a==='galaxy-reset'){state.galaxyView={x:0,y:0,zoom:1.3};}
  else if(a==='galaxy-region'){openDetail('第一星系 · 区域一','区域内30设施槽。工程与升级自动调度；当前人员 '+crewCount('galaxy')+'/6。当前所看区域和节点保持。');return;}
  else if(a==='galaxy-effects'){const n=state.galaxyNodes[state.galaxyNode];openDetail(n.state==='fog'?'未探索节点':n.name,n.state==='fog'?'类型与效果尚未揭示。':galaxyEffect[n.family]+'；当前 '+(n.state==='complete'||n.state==='upgrading'?'Lv.'+n.level+'贡献生效':'尚未生效')+'。具体当前/完成后因子由星系展示模型提供，本画面不按美术等级重新推导收益。');return;}
  else if(a==='galaxy-crew') {state.crewDraft='galaxy';goRoute('crew');return;}
  else if(a==='crew-apply') {const reason=crewAdmission();if(reason){state.crewError=reason;}else{const m=state.crewMembers[state.crewId];Object.assign(m,{job:state.crewDraft,targetPlanet:state.crewPlanet,targetFacility:state.crewFacility,mode:state.crewMode});state.crewError='';if(m.job==='planet-explore'){const p=state.planets.find(p=>p.id===m.targetPlanet);p.running=true;p.elapsed='0';p.duration=p.id==='1'?'60':'26';}syncDemoCrewTargets();notify('派遣已接纳，人物与对应目标人数同步');}}
  else if(a==='crew-release') {if(state.onlineTask.crewId===state.crewId&&['running','ready'].includes(state.onlineTask.status)){openDetail('当前成员被任务保留','先停止自动任务或解决待领回执，再释放当前人员。');return;}state.crewMembers[state.crewId].job='idle';syncDemoCrewTargets();notify('当前成员已释放，目标人数与缺人暂停状态更新');}
  else if(a==='crew-target') {if(state.crewDraft.startsWith('planet-')){state.planetId=state.crewPlanet;selectedPlanet().facilitySelection=state.crewFacility;}goRoute(state.crewDraft==='galaxy'?'galaxy':state.crewDraft==='idle'?'crew':state.crewDraft.startsWith('planet-')?'planet':state.crewDraft);return;}
  else if(a==='research-apply-iron'||a==='research-apply-uranium') {const iron=a==='research-apply-iron';const draft=iron?state.researchDraft:state.researchUraniumDraft;if(!validAmountDraft(draft)){state.researchError=(iron?'铁':'铀')+'投入需为非负整数金额；当前生效值保持，草稿可继续修正。';}else{if(iron)state.researchBudget=state.researchDraft;else state.researchUranium=state.researchUraniumDraft;state.researchError='';state.researchFeedback=(iron?'铁':'铀')+'投入已应用，另一资源与研究工作量保持。';notify('本资源投入已应用');}}

  else if(a==='research-select') {state.researchDrawer=true;}
  else if(a==='research-close') {state.researchDrawer=false;}
  else if(a==='research-reset') {state.researchDraft=state.researchBudget;state.researchUraniumDraft=state.researchUranium;state.researchError='';state.researchFeedback='草稿已还原为当前生效值。';}
  else if(a==='research-intent-now') {const rows=budgetPreview(state.researchIntent);state.researchDraft=rows[0].rate;state.researchUraniumDraft=rows[1].rate;state.researchFeedback='即时预算草稿已生成，当前投入保持；铁和铀分别接纳，失败不撤销已成功资源。';}
  else if(a==='research-intent-auto') {state.researchAuto=true;state.researchAutoDraft=true;state.researchRatio=String(state.researchIntent);state.researchRatioDraft=String(state.researchIntent);state.researchFeedback='持续收入比例已设置；下一60游戏秒刷新点才重算，当前投入保持。';}
  else if(a==='research-auto-apply') {if(!Number.isFinite(Number(state.researchRatioDraft))||Number(state.researchRatioDraft)<0||Number(state.researchRatioDraft)>100){state.researchError='比例需在0–100%以内，当前预算设置保持。';render();return;}state.researchAuto=state.researchAutoDraft;state.researchRatio=state.researchRatioDraft;state.researchFeedback='预算设置已生效，下一个60游戏秒刷新点采用；当前投入金额尚未重算。';}
  else if(a==='research-crew') {state.crewDraft='research';goRoute('crew');return;}
  else if(a==='equip-one'||a==='equip-ten'||a==='equip-max-mode') {state.equipmentMode=a==='equip-one'?'one':a==='equip-ten'?'ten':'max';state.candidate=false;}
  else if(a==='hyper-manual') {goRoute('hyperspace/manual');return;}
  else if(a==='manual-start') {if(!['running','ready'].includes(state.manualTask.status)){state.manualTask={status:'running',route:state.routeId,run:'manual-02',receipt:null};notify('手动挑战已开始，在线任务保持');}goRoute('hyperspace/routes');return;}
  else if(a==='online-start') {if(!['running','ready'].includes(state.onlineTask.status)){state.onlineTask={status:'running',route:state.routeId,run:'online-02',receipt:null,mode:'single',crewId:null};notify('单次挂机已开始，手动挑战保持');}}
  else if(a==='online-auto') {const task=state.onlineTask;if(task.status==='running'&&task.mode==='auto'){if(task.crewId&&state.crewMembers[task.crewId]?.job==='hyperspace')state.crewMembers[task.crewId].job='idle';state.onlineTask={...task,status:'idle',crewId:null};syncDemoCrewTargets();notify('自动任务已停止，Started任务不生成奖励');}else if(task.status==='ready'){goRoute('hyperspace/receipt/online');return;}else{const candidates=Object.entries(state.crewMembers).filter(([id,m])=>m.available&&m.job==='idle');openDetail('开始自动挂机 · '+routeName(),`<label>选择空闲船员<select id="online-crew">${candidates.map(([id,m])=>`<option value="${id}">${m.name} · Lv.${m.level}</option>`).join('')}</select></label><p>确认开始后，由在线任务接纳并保留该成员；普通派遣入口不能建立此占用。</p>${control('online-auto-confirm','确认开始并保留人员','primary',!candidates.length)}`);return;}}
  else if(a==='online-auto-confirm'){const id=$('#online-crew')?.value,m=state.crewMembers[id];if(!m||!m.available||m.job!=='idle'){notify('所选成员已不可用，任务未开始');return;}state.onlineTask={status:'running',route:state.routeId,run:'online-auto-demo-02',receipt:null,mode:'auto',crewId:id};m.job='hyperspace';$('#inspect-detail').close();notify('演示任务已接纳，路线与保留人员绑定本任务');}
  else if(a==='receipt-manual'||a==='receipt-online') {goRoute('hyperspace/receipt/'+a.split('-')[1]);return;}
  else if(a==='claim-manual'||a==='claim-online') {const key=a==='claim-manual'?'manualTask':'onlineTask';if(state[key].status==='ready'){state[key]={...state[key],status:'claimed'};notify((key==='manualTask'?'手动':'在线')+'回执已领取；另一任务保持');goRoute('hyperspace/warehouse');return;}}

  else if(a.startsWith('drone-pick-')) {const id=a.slice(11);state.droneId=id;state.droneSelection=state.droneSelection.includes(id)?state.droneSelection.filter(x=>x!==id):[...state.droneSelection,id];invalidateForge();}
  else if(a.startsWith('drone-detail-')) {state.droneId=a.slice(13);invalidateForge();goRoute('hyperspace/drone');return;}
  else if(a==='warehouse-formation') {state.formationDraft=[...state.droneSelection];state.formationPreview=null;goRoute('hyperspace/formation');return;}
  else if(a==='warehouse-forge') {state.droneId=state.droneSelection[0];invalidateForge();goRoute('hyperspace/forge');return;}
  else if(a==='drone-to-formation') {state.formationDraft=[state.droneId];state.formationPreview=null;goRoute('hyperspace/formation');return;}
  else if(a==='drone-to-forge') {invalidateForge();goRoute('hyperspace/forge');return;}
  else if(a==='formation-set') {state.formationDraft=[state.droneId];state.formationPreview=null;}
  else if(a==='formation-preview') {state.formationPreview={equip:state.formationDraft.filter(id=>!state.equippedDrones.includes(id)),remove:state.equippedDrones.filter(id=>!state.formationDraft.includes(id))};}
  else if(a==='formation-confirm') {if(state.formationPreview){state.equippedDrones=[...state.formationDraft];state.formationPreview=null;notify('无人机编队已应用，普通舰体装备未改变');}}
  else if(a==='formation-cancel') {state.formationPreview=null;}
  else if(a==='forge-preview') {state.forgePreview={id:state.droneId,operation:state.forgeOperation,before:drones[state.droneId].affix};state.forgeResult=null;}
  else if(a==='forge-confirm') {const preview=state.forgePreview;if(preview&&preview.id===state.droneId&&preview.operation===state.forgeOperation){state.forgeResult={id:preview.id,before:preview.before,after:'攻击 +10%'};drones[preview.id].affix='攻击 +10%';state.forgePreview=null;notify('改造已完成，实际结果与支付显示在当前对象下');}}
  else if(a==='forge-cancel') {state.forgePreview=null;}
  else if(a==='warehouse-filter') {goRoute('hyperspace/filter');return;}
  else if(a==='warehouse-sealed') {goRoute('hyperspace/sealed');return;}
  else if(a==='drone-hanging') {goRoute('hyperspace/hanging');return;}
  else if(a==='drone-favorite') {goRoute('hyperspace/protection');return;}
  else if(a==='filter-apply') {state.filter={...state.filterDraft};notify('过滤规则已应用，原仓库选择保持');}
  else if(a==='filter-import') {state.importFilterText=$('#filter-source').value;try{const parsed=JSON.parse(state.importFilterText);state.importFilterValid=['稀有以下','普通','史诗以下'].includes(parsed.quality)&&['保留','拆解'].includes(parsed.action);state.importFilterCandidate=parsed;}catch{state.importFilterValid=false;}goRoute('hyperspace/filter-import');return;}
  else if(a==='filter-import-confirm') {if(state.importFilterValid){state.filter={...state.importFilterCandidate};state.filterDraft={...state.filter};goRoute('hyperspace/filter');notify('导入规则已替换原规则');return;}}
  else if(a==='filter-export') {goRoute('hyperspace/filter-export');return;}
  else if(a==='materials-exchange') {state.materialReceipt='实际支付100源材料，收到20目标材料；余额140 / 80。';notify('材料兑换完成');}
  else if(a==='save-open') {goRoute('settings/save');return;}
  else if(a==='archive-tutorial'){goRoute('archive/tutorial');return;}
  else if(a==='tutorial-continue'){state.archive.guidePaused=false;notify('引导暂停已释放；其他暂停原因保持');}
  else if(a==='tutorial-target'){goRoute({equip:'equipment',upgrade:'equipment',pickup:'archive/statistics',retreat:'equipment',clear:'archive/notifications'}[state.archive.tutorial]);return;}
  else if(a==='settings-audio'){goRoute('settings/preferences');return;}
  else if(a==='save-directory-apply'){const m=state.maintenance;if(!m.directoryDraft.trim()){m.feedback='候选目录为空，当前目录保持。';}else{m.directory=m.directoryDraft;m.feedback='演示目录已切换，当前进度仍需请求保存。';m.save='dirty';}}
  else if(a==='save-picker'){openDetail('选择保存目录',`<label>目录<select id="directory-choice"><option>D:/SpaceIdle/save</option><option>D:/SpaceIdle/backup</option></select></label><p>选取后写入候选目录；应用后才切换当前目录。</p>${control('save-picker-use','选取此目录','primary')}`);return;}
  else if(a==='save-picker-use'){state.maintenance.directoryDraft=$('#directory-choice').value;$('#inspect-detail').close();notify('候选目录已选取，当前目录保持');}
  else if(a==='save-retry'){state.maintenance.save='queued';state.maintenance.feedback='保存请求已排队；收到持久完成状态之前不显示已保存。';}
  else if(a==='save-backup'){goRoute('settings/danger/import');state.maintenance.importSource='backup-02.json';state.dangerPreview=null;return;}
  else if(a.startsWith('danger-')&&['reforge','import','new'].includes(a.slice(7))) {const kind=a.slice(7);state.dangerKind=kind;state.dangerPreview=null;state.dangerResult=null;goRoute('settings/danger/'+kind);return;}
  else if(a==='danger-preview') {const m=state.maintenance;state.dangerSource=state.dangerKind==='reforge'?selectedPlanet().name:state.dangerKind==='import'?m.importSource:m.newDirectory;m.dangerError='';if(state.dangerKind==='import'&&!['backup-02.json','backup-03.json'].includes(m.importSource)){state.dangerPreview=null;m.dangerError='候选校验未通过：当前演示仅提供backup-02.json与backup-03.json有效响应；原文件与当前会话保持。';render();return;}if(state.dangerKind==='new'&&!m.newDirectory.trim()){m.dangerError='目标目录为空，当前航程保持。';render();return;}state.dangerPreview={id:'preview-'+(++m.previewSerial),kind:state.dangerKind,source:state.dangerSource,planetId:state.planetId,retained:[...m.retained],clearSettings:m.clearSettings};state.dangerResult=null;}
  else if(a==='danger-confirm') {const p=state.dangerPreview,m=state.maintenance;if(p&&p.kind===state.dangerKind&&p.source===state.dangerSource&&p.planetId===state.planetId&&p.retained.join()===m.retained.join()&&p.clearSettings===m.clearSettings){state.dangerResult=p.kind==='import'?'演示结果：候选已替换内存会话，持久化待重试；原有效文件保留。':p.kind==='reforge'?'演示结果：'+p.source+'重铸会话已接纳；星球探索、建筑与星系进度保留。':'演示结果：新航程已建立至'+p.source+'，等待首次持久化；原文件保留。';m.save=p.kind==='import'?'failed':'queued';m.feedback=p.kind==='import'?'候选已替换内存会话，写盘失败待重试；旧有效文件保留。':'新会话已接纳；持久化请求排队，等待完成。';state.dangerPreview=null;notify('本次演示结果已保留，旧预览不能重复提交');}}
  else if(a==='danger-cancel') {state.dangerPreview=null;notify('已取消预览，当前航程不变');}
  else if(a==='back') {back();return;}
  else if(a==='catalog') {goRoute('catalog');return;}
  else if(a==='expand') {state.collapsed=false;}
  else if(a==='close-detail') {$('#inspect-detail')?.close();return;}
  else {
    const details={hull:['舰体选择','当前巡洋舰。候选舰体的槽位、开放条件和影响在确认前比较。'],attributes:['属性明细','当前基础值、最终效果、盾甲容量与临时状态分别查看。'], 'equip-all':['全部槽位批量预览','本次范围：3武器槽与2防御槽。逐槽成交、数量和费用需在本预览内确认，当前未提交。'], 'reactor-buy':['核心购级报价','核心 Lv.1 → Lv.2，本次费用10铀。新容量与分配结果由反应炉公开报价/实际模型提供，不由前端增长公式计算。'], 'galaxy-effects':['外环平台效果','当前Lv.2效果与目标Lv.3完成后的效果分别显示；升级完成自动接纳。'], 'galaxy-pan':['地图视角','当前区域一、外环平台仍选中；返回后视角保持。'], 'planet-detail':['轨道船坞','当前设施门槛、施工次数、实际人员与待领取状态。'], 'planet-other':['星球选择','当前起源星。切球只改变所看对象，不取消其探索或施工。']};
    const [title,text]=details[a]||['当前对象详情','已进入所选对象的详情，返回后对象与草稿保持。'];openDetail(title,text);return;
  }
  render();
}
document.addEventListener('click',event=>{
  const button=event.target.closest('[data-family],[data-module],[data-group],[data-slot],[data-action],[data-route],[data-context-route],[data-crew],[data-drone],[data-hyper-route],[data-study],[data-facility],[data-galaxy-node],[data-enhance-node],[data-enhance-choice],[data-tutorial],[data-intel],[data-notification-seen],[data-notification-read]');
  if(!button) return;
  if(button.dataset.family) {rememberScroll();state.family=button.dataset.family;render();}
  else if(button.dataset.module) setModule(button.dataset.module);
  else if(button.dataset.group) switchGroup(button.dataset.group);
  else if(button.dataset.slot!==undefined) {state.slot=Number(button.dataset.slot);state.candidate=false;render();}
  else if(button.dataset.route) goRoute(button.dataset.route);
  else if(button.dataset.contextRoute) {const target=button.dataset.contextRoute;if(target==='crew'&&state.group==='hyperspace'&&state.onlineTask.crewId){state.crewId=state.onlineTask.crewId;state.crewDraft=state.crewMembers[state.crewId].job;}goRoute(target.includes('/')?target:(state.moduleLast[target]||target));}
  else if(button.dataset.crew) {state.crewId=button.dataset.crew;const m=state.crewMembers[state.crewId];state.crewDraft=m.job==='hyperspace'?'idle':m.job;state.crewPlanet=m.targetPlanet;state.crewFacility=m.targetFacility;state.crewMode=m.mode;state.crewError='';render();}
  else if(button.dataset.drone) {state.droneId=button.dataset.drone;state.formationPreview=null;invalidateForge();state.dangerPreview=null;notify('已更换无人机对象，需要重新预览');render();}
  else if(button.dataset.hyperRoute) {state.routeId=button.dataset.hyperRoute;render();}
  else if(button.dataset.tutorial){state.archive.tutorial=button.dataset.tutorial;render();}
  else if(button.dataset.intel){state.archive.enemy=button.dataset.intel;render();}
  else if(button.dataset.notificationSeen){state.archive.notifications.find(n=>n.key===button.dataset.notificationSeen).seen=true;render();}
  else if(button.dataset.notificationRead){state.archive.notifications.find(n=>n.key===button.dataset.notificationRead).read=true;render();}
  else if(button.dataset.enhanceNode){const [id,node]=button.dataset.enhanceNode.split(':');state.enhance.effect=id;state.enhance.node=Number(node);state.enhance.choice='';goRoute('enhancement/branch/'+id+'/'+node);}
  else if(button.dataset.enhanceChoice){state.enhance.choice=button.dataset.enhanceChoice;render();}
  else if(button.dataset.galaxyNode){if(window.cityDragged){window.cityDragged=false;return;}state.galaxyNode=button.dataset.galaxyNode;render();}
  else if(button.dataset.facility){selectedPlanet().facilitySelection=button.dataset.facility;render();}
  else if(button.dataset.study) {state.researchId=button.dataset.study;state.researchDrawer=false;state.researchState='running';state.researchFeedback='已切换设备，原研究工作量保留。';render();}
  else action(button.dataset.action);
});
document.addEventListener('input',event=>{
  if(event.target.dataset.reactorShare!==undefined){state.alloc[Number(event.target.dataset.reactorShare)]=Number(event.target.value);state.reactorError='';state.reactorReceipt='';state.reactorIntent='custom';event.target.closest('label').querySelector('b').textContent=event.target.value+'%';$('#action-dock').innerHTML=dock();}
  if(event.target.id==='research-intent'){state.researchIntent=Number(event.target.value);const box=document.createElement('div');box.innerHTML=researchIntentPanel();$('.budget-intent output').textContent=state.researchIntent+'%';$('.budget-comparison').innerHTML=box.querySelector('.budget-comparison').innerHTML;}

  if(event.target.id==='research-budget') state.researchDraft=event.target.value;
  if(event.target.id==='research-uranium')state.researchUraniumDraft=event.target.value;
  if(event.target.id==='research-ratio')state.researchRatioDraft=event.target.value;
  if(event.target.id==='danger-source') {state.dangerSource=event.target.value;state.dangerPreview=null;state.dangerResult=null;const preview=$('.transaction-preview');if(preview)preview.remove();notify('来源已改变，旧预览失效');}
  if(['save-directory','import-source','new-directory'].includes(event.target.id)){const key={'save-directory':'directoryDraft','import-source':'importSource','new-directory':'newDirectory'}[event.target.id];state.maintenance[key]=event.target.value;state.dangerPreview=null;state.dangerResult=null;document.querySelector('.transaction-preview')?.remove();}
  if(event.target.id==='material-amount') state.materialDraft=event.target.value;
  if(event.target.id==='filter-source') state.importFilterText=event.target.value;
  if(['research-budget','research-uranium'].includes(event.target.id)){const dirty=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium;const flag=$('.investment-title small');if(flag)flag.textContent=dirty?'草稿未应用，当前生效值保持':'当前投入已生效';const context=$('[data-context-route="research"] span');if(context)context.textContent=summary('research');}
});
document.addEventListener('change',event=>{
  const id=event.target.id,value=event.target.value;
  if(event.target.dataset.reactorShare!==undefined)render();
  if(id==='danger-planet'){state.planetId=value;state.dangerPreview=null;state.dangerResult=null;render();}
  if(event.target.dataset.retainDrone){const id=event.target.dataset.retainDrone;state.maintenance.retained=event.target.checked?[...state.maintenance.retained,id]:state.maintenance.retained.filter(x=>x!==id);state.dangerPreview=null;state.dangerResult=null;render();}
  if(id==='new-clear-settings'){state.maintenance.clearSettings=event.target.checked;state.dangerPreview=null;render();}
  if(id.startsWith('pref-')){const m=state.maintenance;if(id==='pref-music')m.music=event.target.checked;if(id==='pref-effects')m.effects=event.target.checked;if(id==='pref-skip')m.skip=event.target.checked;if(id==='pref-damage')m.damage=value;if(id==='pref-interval'){if(/^\d+$/.test(value)&&Number(value)<=86400)m.interval=value;else m.feedback='自动保存间隔需为0–86400现实秒；原值保持。';}render();}
  if(id==='research-auto-toggle')state.researchAutoDraft=event.target.checked;
  if(id==='planet-select'){state.planetId=value;state.planet=selectedFacility().state;notify('已切换所看星球，各星球任务保持');render();}
  if(id==='crew-target') {state.crewDraft=value;state.crewError='';render();}
  if(id==='crew-planet'){state.crewPlanet=value;state.crewFacility=state.planets.find(p=>p.id===value).facilitySelection;render();}
  if(id==='crew-facility'){state.crewFacility=value;render();}
  if(id==='crew-mode'){state.crewMode=value;render();}
  if(id==='forge-operation') {state.forgeOperation=value;invalidateForge();render();}
  if(id==='filter-quality') state.filterDraft.quality=value;
  if(id==='filter-action') state.filterDraft.action=value;
});
$('#collapse').onclick=()=>{rememberScroll();state.collapsed=!state.collapsed;render();};
$('#pause').onclick=()=>{state.paused=!state.paused;notify(state.paused?'已暂停，界面仍可查看':'航程已恢复');render();};
$('#scenario-open').onclick=()=>$('#scenario').showModal();
$('#scenario-close').onclick=()=>$('#scenario').close();
$('#assembly-toggle').onclick=()=>{document.body.classList.toggle('show-assembly');$('#assembly-toggle').classList.toggle('active',document.body.classList.contains('show-assembly'));};
for(const key of ['reactor','equipment','planet','galaxy']) $('#'+key+'-case').onchange=event=>{
  state[key]=event.target.value;if(key==='reactor'){state.reactorIntent='custom';state.reactorReceipt='';}
  if(key==='reactor') {state.actual=event.target.value==='idle'?[0,0,0,0]:[45,35,20,0];state.alloc=event.target.value==='draft'?[60,35,5,0]:event.target.value==='rejected'?[55,35,20,0]:[...state.actual];state.reactorError=event.target.value==='rejected'?'额度不足，实际供能保持原值。':'';}
  if(key==='galaxy'){const n=state.galaxyNodes[state.galaxyNode];n.state=event.target.value;n.progress=n.state==='complete'?100:n.state==='building'?62:n.state==='upgrading'?48:0;n.level=n.state==='upgrading'?2:n.state==='complete'?3:1;}
  if(key==='planet'){const p=selectedPlanet(),f=selectedFacility();f.state=event.target.value==='paused'?'building':event.target.value;f.work=f.state==='ready'||f.state==='owned'?f.required:111;if(event.target.value==='paused'){for(const m of Object.values(state.crewMembers))if(m.job==='planet-build'&&m.targetPlanet===p.id&&m.targetFacility===f.id)m.job='idle';}if(event.target.value==='building'){Object.assign(state.crewMembers.navigator,{job:'planet-build',targetPlanet:p.id,targetFacility:f.id});}if(f.state==='ready'||f.state==='owned'){p.exploration=Math.max(p.exploration,210);for(const m of Object.values(state.crewMembers))if(m.job==='planet-build'&&m.targetPlanet===p.id&&m.targetFacility===f.id)m.job='idle';}}
  if(key==='equipment'){state.candidate=event.target.value==='compare';state.cooldowns=event.target.value==='cooldown'?{[state.slot]:10}:{};if(event.target.value==='cooldown')state.equipment='normal';}
  render();
};
for(const kind of ['manual','online']) $('#'+kind+'-task-case').onchange=event=>{const key=kind==='manual'?'manualTask':'onlineTask';state[key]={...state[key],status:event.target.value,route:kind==='manual'?'pulse':'missile'};render();};
$('#guide-case').onchange=event=>{state.archive.guidePaused=event.target.value==='first';goRoute('archive/tutorial');};
$('#save-case').onchange=event=>{state.maintenance.save=event.target.value;state.maintenance.feedback='';render();};
$('#enhance-funds').onchange=event=>{state.enhance.funds=event.target.value==='enough';render();};
$('#research-case').onchange=event=>{state.researchState=event.target.value;render();};
$('#research-unlocks').onchange=event=>{state.researchUnlocked=event.target.value==='all'?Object.keys(studies):['equipment_finishing','uranium_extraction','weapon_accuracy','equipment_reinforcement','resource_refining','singularity'];if(!state.researchUnlocked.includes(state.researchId))state.researchId=state.researchUnlocked[0];render();};
document.addEventListener('visibilitychange',()=>document.body.classList.toggle('page-hidden',document.hidden));
window.addEventListener('resize',fitBattle);
window.G1={state,render,setModule,setRoute:goRoute,fitBattle,summary};
render();

let cityDrag=null;
document.addEventListener('pointerdown',e=>{const map=e.target.closest('.city-map');if(!map||e.target.closest('button'))return;cityDrag={id:e.pointerId,x:e.clientX,y:e.clientY,origin:{...state.galaxyView},moved:false,map};window.cityDragged=false;});
document.addEventListener('pointermove',e=>{if(!cityDrag||e.pointerId!==cityDrag.id)return;const d=cityDrag,dx=e.clientX-d.x,dy=e.clientY-d.y;if(Math.hypot(dx,dy)>6)d.moved=true;if(!d.moved)return;window.cityDragged=true;const scale=800/d.map.getBoundingClientRect().width;state.galaxyView.x=d.origin.x+dx*scale;state.galaxyView.y=d.origin.y+dy*scale;const v=state.galaxyView;$('#city-transform')?.setAttribute('transform',`translate(${v.x} ${v.y}) translate(400 270) scale(${v.zoom}) translate(-400 -270)`);});
document.addEventListener('pointerup',()=>{cityDrag=null;});
document.addEventListener('wheel',e=>{if(!e.target.closest('.city-map'))return;e.preventDefault();state.galaxyView.zoom=Math.max(.65,Math.min(2,state.galaxyView.zoom+(e.deltaY<0?.1:-.1)));render();},{passive:false});
