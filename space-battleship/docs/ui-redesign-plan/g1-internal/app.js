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
  alloc: [45,35,20,0], actual: [45,35,20,0], reactorError: '',
  slot:0, fitKeys:['laser','missile','longLaser','shield','armour'], levels: [24,18,18,18,18], fits: ['脉冲炮','舰载导弹','长激光','护盾发生器','装甲'],
  attributes:['12.4 K','12.4 K','12.4 K','84.0 K','84.0 K'], candidate: false, equipmentMode: 'one', planetAuto: true, planetId: 'origin', galaxyNode: 'outer',
  crewId: 'lin', crewDraft: 'planet-build',
  crewMembers: {lin: {name: '林夏', job: 'planet-build'}, zhou: {name: '周砚', job: 'galaxy'}, he: {name: '何宁', job: 'idle'}},
  researchId:'equipment_finishing', researchBudget:'800000', researchDraft:'800000', researchUranium:'120000', researchUraniumDraft:'120000', researchAuto:false, researchRatio:'25', researchAutoDraft:false, researchRatioDraft:'25', researchState:'running', researchDrawer:false, researchUnlocked:['equipment_finishing','uranium_extraction','weapon_accuracy','equipment_reinforcement','resource_refining','singularity'], researchError:'', researchFeedback:'', cooldowns:{},
  droneId: 'd2', droneSelection: ['d2'], equippedDrones: ['d1'], formationDraft: ['d2'], formationPreview: null,
  forgePreview: null, forgeResult: null, forgeOperation: 'reroll',
  filter: {quality: '稀有以下', action: '保留'}, filterDraft: {quality: '稀有以下', action: '保留'},
  materialDraft: '100', materialReceipt: '', routeId:'pulse', manualTask:{status:'idle',route:'pulse',run:'manual-01',receipt:null}, onlineTask:{status:'idle',route:'missile',run:'online-01',receipt:null,mode:'single',crewId:null},
  dangerKind: 'reforge', dangerSource: '起源星', dangerPreview: null, dangerResult: null,
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
  '24.2 K':{one:'25.0 K',max:'34.2 K'},'25.0 K':{one:'25.8 K',max:'35.3 K'},'116.0 K':{one:'119.2 K',max:'129.0 K'},
  '12.4 K':{one:'13.1 K',max:'16.3 K'},'13.1 K':{one:'13.8 K',max:'16.9 K'},'13.8 K':{one:'14.5 K',max:'17.6 K'},
  '14.5 K':{one:'15.2 K',max:'18.3 K'},'16.3 K':{one:'16.9 K',max:'20.4 K'},'15.8 K':{one:'16.5 K',max:'19.6 K'},
  '84.0 K':{one:'87.2 K',max:'96.0 K'},'87.2 K':{one:'90.4 K',max:'99.2 K'},'92.0 K':{one:'95.2 K',max:'104.0 K'},'96.0 K':{one:'99.2 K',max:'108.0 K'}
};
const studies = SceneModels.research;
const jobs = {idle:'空闲', 'planet-build':'起源星·轨道船坞施工', 'planet-explore':'起源星探索', galaxy:'曙光星系建设', hyperspace:'超空间在线挂机', research:'AI科研续研岗位'};
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
const crewCount = job => Object.values(state.crewMembers).filter(member=>member.job===job).length;
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
  if(route==='crew') {if(state.group==='hyperspace'){const task=state.onlineTask;return task.crewId?state.crewMembers[task.crewId].name+' · '+routeName(task.route)+' / '+taskStatus(task):'当前在线任务无保留船员';}const m=state.crewMembers[state.crewId];return `${m.name} · ${jobs[m.job]}`;}
  if(route==='planet') return `轨道船坞 · ${planetStatus[state.planet][0]}`;
  if(route==='galaxy') return `外环平台 · ${galaxyStatus[state.galaxy][0]}`;
  if(route==='hyperspace/routes') return `手动·${routeName(state.manualTask.route)} ${taskStatus(state.manualTask)} / 挂机·${routeName(state.onlineTask.route)} ${taskStatus(state.onlineTask)}`;
  if(route==='hyperspace/formation') return `${state.equippedDrones.map(id=>drones[id].name).join(' / ')}${state.formationDraft.join()!==state.equippedDrones.join()?' · 有候选':''}`;
  if(route==='settings/danger/reforge') return state.dangerPreview?'预览待确认':state.dangerResult?'最近结果可查':'重铸 / 导入 / 新游戏';
  if(route==='settings') return '最近进度已写入';
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
  const before=state.reactor==='idle'?null:effectSnapshots[state.actual.join()], after=effectSnapshots[state.alloc.join()];
  const keys=['attack','defence','income','income'];
  const machine=i=>{
    const art=SceneModels.reactor[ids[i]],powered=state.actual[i]+(i===0?free:0)>0;
    return `<figure class="device-workpoint device-${ids[i]} ${powered?'powered':'unpowered'}" data-device="${i}" data-port-x="${art.power_in[0]}" data-port-y="${art.power_in[1]}"><figcaption><b>${names[i]}</b><small>${i===2?'敌掉铁基础量':i===3?'直接碎片':i===0?'武器普通值':'防御普通值'} ${before?.[keys[i]]||'×1.00'}${changed()?` → <strong>${after?.[keys[i]]||'待预览'}</strong>`:''}</small></figcaption><img src="${art.path}" alt="${names[i]}独立设备"><div class="machine-readout"><span>${powered?'供能中':'待机'}</span><b data-readout="manual_supply">${state.actual[i]}</b><small data-readout="free_supply">免费 ${i===0?free:0}</small><small data-readout="effective_supply">有效 ${state.actual[i]+(i===0?free:0)}</small></div><div class="machine-controls">${control('minus-'+i,'−')}${control('reactor-amount-'+i,(changed()?'草稿 ':'分配 ')+state.alloc[i],'quiet')}${control('plus-'+i,'+')}</div></figure>`;
  };
  return moduleHead('反应炉机舱','核心 Lv.1 · 手动预算100 · 免费供能'+free,`<span class="pill ${changed()?'warn':''}">${changed()?'分配待应用':'当前已生效'}</span>`)+
    `<div class="allocation-task"><div><b>保持防御，优先武器供能</b><span>从熔炼暂调15单位到武器；核心容量不变。</span></div>${control('reactor-task','查看调配方案')}</div>`+
    `<div class="reactor-room"><div class="reactor-grid reactor-room-grid"><svg class="reactor-pipes ${!state.paused&&sum(state.actual)>0?'running':''}" aria-label="核心出口、主管、设备入口统一连接"></svg>${machine(0)}${machine(2)}<div class="reactor-core-assembly ${sum(state.actual)+free>0&&!state.paused?'running':''}"><img src="${SceneModels.reactor.core.path}" alt="反应炉独立核心"><div class="reactor-energy"></div><div class="core-instrument"><small>当前有效供能</small><b>${sum(state.actual)+free}</b></div></div>${machine(1)}${opened?machine(3):''}<span class="trunk-label">供能主管</span></div></div>`+
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
  if(state.equipmentMode==='ten') return {label:'购买10级',current,next:defence?'116.0 K':'24.2 K',price:'5.80 M 铁',action:'equip-buy'};
  if(state.equipmentMode==='max') return {label:'本槽MAX · 4级',current,next:response?.max||'待取得新报价',price:'2.10 M 铁',action:'equip-buy'};
  return {label:'购买1级',current,next:response?.one||'待取得新报价',price:'0.42 M 铁',action:'equip-buy'};
}
function equipment() {
  const q=equipmentQuote();
  const mounts=SceneModels.previewMounts;
  const point=(i)=>{const p=mounts[i];return {x:50+(p[0]-384)/768*100,y:50+(p[1]-384)/768*100};};
  return moduleHead('巡洋舰 · 装配台','3个武器槽 / 2个防御槽',`<span class="pill">${state.fits[state.slot]} · Lv.${state.levels[state.slot]}</span>`)+
    `<div class="outfit-room"><div class="outfit-rig"><div class="rig-floor"></div><div class="rig-ship"><img src="${asset}ui/ships/fleet_20261019/03-cruiser.png" alt="巡洋舰完整静态预览">${mounts.map((p,i)=>{const a=point(i);return `<button class="mount-dot ${state.slot===i?'selected':''}" data-slot="${i}" style="left:${a.x}%;top:${a.y}%" aria-label="选择武器槽${i+1}">${i+1}</button>`;}).join('')}</div><div class="rig-weapon-labels">${[0,1,2].map(i=>`<button data-slot="${i}" class="rig-slot ${state.slot===i?'selected':''}"><small>武器 ${i+1}</small><b>${state.fits[i]}</b><span>Lv.${state.levels[i]}</span></button>`).join('')}</div><div class="rig-defence-labels">${[3,4].map(i=>`<button data-slot="${i}" class="rig-slot ${state.slot===i?'selected':''}"><small>${i===3?'首防御 · 必装':'防御 2'}</small><b>${state.fits[i]}</b><span>Lv.${state.levels[i]}</span></button>`).join('')}</div></div><div class="outfit-console"><span class="eyebrow">${state.slot<3?'WEAPON '+(state.slot+1):'DEFENCE '+(state.slot-2)}</span><h2>${state.fits[state.slot]}</h2><div class="equipment-object-icon"><img src="${asset}ui/equipment/${slotIcon()}" alt=""></div><div class="compare-cols"><div><small>当前${state.slot<3?'普通攻击基值':'容量'}</small><b>${q.current}</b></div><div><small>${q.label}</small><b>${q.next}</b></div></div><div class="comparison-cadence">${comparisonCycle()}</div><div class="compare-price">本次费用<b>${q.price}</b></div><div class="purchase-modes">${control('equip-one','+1',state.equipmentMode==='one'&&!state.candidate?'active':'')}${control('equip-ten','+10',state.equipmentMode==='ten'&&!state.candidate?'active':'')}${control('equip-max-mode','MAX',state.equipmentMode==='max'&&!state.candidate?'active':'')}</div><p class="sub">${state.slot===3?'首防御槽不可卸空，可换合法防御类型。':state.candidate?'候选未生效；确认后再更新当前装配。':'槽位等级在更换装备后保留。'}</p></div></div>`+
    (currentCooldown()?`<div class="note warn">武器/防御槽${state.slot<3?state.slot+1:state.slot-2}换装冷却剩余${currentCooldown()}秒，其他槽位分别判断。</div>`:'')+
    (state.equipment==='poor'?`<div class="note bad">铁不足，本次需要${q.price}。所选槽位保持。</div>`:'')+
    `<div class="secondary-actions">${control('hull','比较五舰')}${control('equip-all','全部槽位批量预览')}${control('attributes','属性与贡献明细','quiet')}</div>`;
}

function planet() {
  const [status,pct,desc]=planetStatus[state.planet], count=state.planet==='paused'?0:crewCount('planet-build');
  return moduleHead('起源星 · 轨道发展','探索度84% · 当前设施：轨道船坞',`<span class="pill">${state.planetAuto?'自动探索':'本次完成后停止'}</span>`)+
    `<div class="planet-layout"><div class="planet-view"><div class="orbit"></div><div class="planet-ball"><img src="${asset}planets/toon/origin-surface.svg" alt="起源星"></div><button class="facility-chip" data-action="planet-detail">轨道船坞 · ${status}</button></div><div class="planet-state"><span class="eyebrow">ORBITAL DOCK</span><h2>轨道船坞</h2><span class="pill ${state.planet==='paused'?'warn':'good'}">${status}</span><div class="progress-num">${pct}</div><div class="meter"><i style="width:${pct}"></i></div><div class="sub">施工人员 ${count} / 2<br>${desc}</div><div class="people"><i class="${count===0?'empty':''}"></i><i class="empty"></i></div></div></div>`+
    `<div class="secondary-actions">${control('planet-auto',state.planetAuto?'本次完成后停止':'开启自动探索')}${control('planet-cancel','立即取消探索','danger')}${control('planet-other','其他星球')}${control('planet-buff','累计Buff / 重铸')}</div>`;
}
function galaxy() {
  const [status,pct,desc]=galaxyStatus[state.galaxy];
  return moduleHead('曙光星系 · 外环平台','所选设施与地图对象对应',`<span class="pill">人员 ${crewCount('galaxy')}</span>`)+
    `<div class="map-layout"><div class="galaxy-map"><svg viewBox="0 0 440 350" role="img" aria-label="星系节点结构"><path d="M220 182L105 97M220 182L347 93M220 182L110 285M220 182L345 272" fill="none" stroke="#a5b7a3" stroke-width="10"/><path d="M220 182L347 93" fill="none" stroke="#5b9f96" stroke-width="3" stroke-dasharray="4 5"/><g class="facility-shape"><path d="M190 160L220 140L250 160V201L220 218L190 201Z"/><path d="M85 82L105 69L126 82V112L105 126L85 112Z"/><path d="M90 270L110 257L130 270V298L110 310L90 298Z"/><path d="M327 258L347 244L368 258V286L347 299L327 286Z"/></g><path data-action="galaxy-node" class="facility-shape selected ${state.galaxy==='fog'?'fog':''}" d="M321 74L347 57L374 74V113L347 131L321 113Z"/><text x="199" y="187" fill="#3c6666" font-size="13">总部</text><text x="300" y="155" fill="#3c7775" font-size="12">外环平台</text></svg><div class="map-caption">区域一 / 外环平台</div></div><div class="planet-state"><span class="eyebrow">OUTER PLATFORM</span><h2>外环平台</h2><span class="pill good">${status}</span><div class="progress-num">${pct}</div><div class="meter"><i style="width:${pct}"></i></div><div class="sub">${desc}<br>${state.galaxy==='upgrading'?'当前Lv.2，升级目标Lv.3':'当前对象：外环平台'}</div></div></div>`+
    `<div class="secondary-actions">${control('galaxy-pan','地图视角')}${control('galaxy-region','其他区域')}</div>`;
}
function research() {
  const study=studies[state.researchId];
  const stopped=state.paused||state.researchState==='paused'||state.researchState==='completed';
  const status=state.researchState==='completed'?'本级研究完成':state.paused||state.researchState==='paused'?'暂停':state.researchState==='unfunded'?'基础研究中 · 投入加速不足':'研究中';
  const dirty=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium;
  return moduleHead('AI科技工厂 · '+study.name,'Lv.'+study.level+' · '+study.effect,`<span class="pill ${stopped?'warn':'good'}">${status}</span>`)+
    `<div class="factory-room ${stopped?'stopped':'working'}"><img class="factory-background" src="${asset}ai_tech_factory/workshop-background-v2.png" alt="AI工厂场景"><img class="factory-machine" src="${asset}ai_tech_factory/${study.image}" alt="${study.name}设备"><img class="factory-probe" src="${asset}ai_tech_factory/inspection-probe-v2.png" alt="当前研究探针"><div class="research-device-status"><span class="eyebrow">CURRENT DEVICE</span><b>${study.name}</b><span>${state.researchState==='completed'?'100%':study.progress}</span><div class="meter"><i style="width:${state.researchState==='completed'?'100%':study.progress}"></i></div><small>工作量 ${state.researchState==='completed'?study.required:study.work} / ${study.required}</small><small>速度 ${study.speed}工作量 / 游戏秒</small><small>${state.researchState==='completed'?'已完成，等待选择下一研究':stopped?'暂停期间不推进':'预计剩余 '+study.remaining+'（游戏时间）'}</small></div><button data-action="research-select" class="factory-selector">选择研究设备</button></div>`+
    `<div class="investment-console"><div class="investment-title"><div><h3>投入控制台</h3><small>${dirty?'草稿未应用，当前生效值保持':'当前投入已生效'}</small></div>${control('research-reset','还原当前值','quiet')}</div><div class="investment-row"><div class="investment-resource"><label>铁 / 游戏秒<input id="research-budget" value="${escapeText(state.researchDraft)}"></label><span>当前 <b>${escapeText(state.researchBudget)}</b></span>${control('research-apply-iron','应用铁投入','primary')}</div><div class="investment-resource"><label>铀 / 游戏秒<input id="research-uranium" value="${escapeText(state.researchUraniumDraft)}"></label><span>当前 <b>${escapeText(state.researchUranium)}</b></span>${control('research-apply-uranium','应用铀投入','primary')}</div></div>${state.researchError?`<div class="note bad">${state.researchError}</div>`:''}${state.researchFeedback?`<div class="research-feedback">${state.researchFeedback}</div>`:''}<div class="research-automation"><div><label><input type="checkbox" id="research-auto-toggle" ${state.researchAutoDraft?'checked':''}> 自动投入预算</label><label>比例 <input id="research-ratio" type="number" min="0" max="100" step="any" value="${state.researchRatioDraft}">%</label>${control('research-auto-apply','应用预算设置')}<small>当前${state.researchAuto?'开启':'关闭'} · ${state.researchRatio}% · 下个60游戏秒预算刷新点采用</small></div><div><b>岗位自动续研</b><span>${crewCount('research')?'已有人 · 完成后续研最短项目':'当前无人 · 完成后停下'}</span>${control('research-crew','查看科研岗位','quiet')}</div></div></div>`+
    (state.researchDrawer?`<div class="research-drawer"><div class="drawer-head"><div><h2>选择当前研究设备</h2><span>切换保留每项已完成工作量</span></div>${control('research-close','关闭')}</div><div class="study-grid">${state.researchUnlocked.map(id=>{const item=studies[id];return `<button data-study="${id}" class="study-option ${state.researchId===id?'selected':''}"><img src="${asset}ai_tech_factory/${item.image}" alt=""><b>${item.name}</b><span>Lv.${item.level} · ${item.progress}</span><small>${item.effect}</small></button>`;}).join('')}</div></div>`:'');
}

function crew() {
  const member=state.crewMembers[state.crewId];
  return moduleHead('成员与当前任务','选择目标不会先释放当前占用')+
    `<div class="crew-layout"><div class="crew-roster">${Object.entries(state.crewMembers).map(([id,m])=>`<button data-crew="${id}" class="crew-card ${state.crewId===id?'selected':''}"><b>${m.name}</b><small>${jobs[m.job]}</small></button>`).join('')}</div><div class="crew-detail"><span class="eyebrow">CREW MEMBER</span><h2>${member.name}</h2><div class="current-job">当前任务 <b>${jobs[member.job]}</b></div><label>派遣候选 <select id="crew-target">${Object.entries(jobs).map(([id,name])=>`<option value="${id}" ${id===state.crewDraft?'selected':''}>${name}</option>`).join('')}</select></label><div class="note">${state.crewDraft===member.job?'候选与当前任务相同。':'确认后才切换岗位；当前任务仍保持。'}</div><div class="secondary-actions">${control('crew-apply','确认派遣','primary',state.crewDraft===member.job)}${control('crew-release','释放当前占用')}${control('crew-target','查看目标')}${control('back','返回来处','quiet')}</div></div></div>`;
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
  if(state.route==='settings/save') return moduleHead('保存与恢复','目录与实际写盘状态')+`<div class="detail-route"><h2>最近进度已写入</h2><label>目录 <input value="D:/SpaceIdle/save" aria-label="保存目录"></label><p>未保存进度：无 · 最近写入 14:32</p><div class="secondary-actions">${control('save-retry','请求保存','primary')}${control('save-backup','备份与恢复')}${control('danger-import','导入存档')}${control('back','返回维护')}</div></div>`;
  return moduleHead('航行维护','保存、音画设置与危险事务')+`<div class="system-objects"><article class="object-card"><h3>保存与恢复</h3><p>最近写入完成 · 当前无未保存进度</p>${control('save-open','打开目录与保存状态')}</article><article class="object-card"><h3>音画设置</h3><p>音乐开启 · 音效开启 · 伤害数字全部</p>${control('settings-audio','声音与显示')}</article><article class="object-card"><h3>重铸</h3><p>选择星球与保留无人机，先审阅收益与损失。</p>${control('danger-reforge','进入重铸预览')}</article><article class="object-card"><h3>导入 / 新游戏</h3><p>来源、清除与保留先确认；取消不改变当前航程。</p>${control('danger-import','导入')}${control('danger-new','新游戏')}</article></div>`;
}
function danger() {
  const kind=state.route.split('/')[2]||'reforge';
  state.dangerKind=kind;
  const title={reforge:'重铸',import:'导入存档',new:'新游戏'}[kind];
  const preview=state.dangerPreview?.kind===kind?state.dangerPreview:null;
  return moduleHead(title,'当前航程不会因查看或取消而改变')+
    `<div class="danger-route"><div class="transaction-source"><h2>本次${title}对象</h2><label>${kind==='reforge'?'星球':'来源 / 目标目录'} <input id="danger-source" value="${escapeText(state.dangerSource)}"></label>${kind==='reforge'?`<p>保留无人机：${droneNameList([state.droneId])}</p>`:''}${control('danger-preview','生成本次预览','primary')}</div>${preview?`<div class="transaction-preview"><span class="eyebrow">REVIEW BEFORE APPLY</span><h2>${title} · ${escapeText(preview.source)}</h2><div class="loss-grid"><div><b>清除 / 替换</b><p>${kind==='reforge'?'本轮星球探索与建设进度':kind==='import'?'当前会话替换为所选来源':'当前航程进度重置'}</p></div><div><b>收益 / 保留</b><p>${kind==='reforge'?'本次永久收益摘要；保留'+droneNameList([preview.droneId]):kind==='import'?'使用已审阅来源的会话摘要':'建立新航程；设置按本次选择保留'}</p></div></div>${control('danger-confirm','确认本次'+title,'primary')}${control('danger-cancel','取消预览')}</div>`:'<div class="empty-preview">尚无有效预览。修改来源或保留对象后需要重新预览。</div>'}${state.dangerResult?`<div class="receipt"><b>${escapeText(state.dangerResult)}</b></div>`:''}<div class="secondary-actions">${control('back','返回原工作点','quiet')}</div></div>`;
}
function overview() {
  const name=modules.find(row=>row[0]===state.module)?.[1]||'工作对象';
  const content=state.module==='enhancement'?[['武器效果与顺位','连发 → 穿透 → 连锁'],['防御效果','当前有效效果与已选分支'],['分支节点','先比较A/B实际效果和门槛'],['购级','购买1级 / 最多10级']]:[['敌方情报','按敌方身份查看已知情报'],['通知','当前未读2条'],['教程回看','选择已经学习的操作'],['航程记录','资源明细与战斗统计']];
  return moduleHead(name,state.module==='enhancement'?'有效效果、顺位与分支':'情报、通知与主动查阅')+`<div class="system-objects">${content.map(([title,text],i)=>`<article class="object-card"><h3>${title}</h3><p>${text}</p>${control('detail-'+i,'展开详情')}</article>`).join('')}</div>`;
}
function catalog() {
  return moduleHead('全系统工作对象','返回所选对象的上次工作位置')+`<div class="system-objects">${modules.map(([id,name,en])=>`<button class="object-card" data-module="${id}" style="text-align:left;white-space:normal;min-height:80px"><span class="eyebrow">${en}</span><h3>${name}</h3></button>`).join('')}</div>`;
}
function dock() {
  if(state.collapsed) return '';
  if(state.module==='equipment') {
    const q=equipmentQuote(), disabled=q.next==='待取得新报价'||state.equipment==='poor'||(q.action==='equip-apply'&&currentCooldown()>0);
    return `<div class="dock-summary"><b>${state.slot<3?'武器槽'+(state.slot+1):'防御槽'+(state.slot-2)} · ${state.fits[state.slot]} Lv.${state.levels[state.slot]}</b><span>${q.label} · ${q.current} → <strong>${q.next}</strong> · ${comparisonCycle()}</span><span>本次费用 <strong>${q.price}</strong></span></div><div class="dock-buttons">${control(q.action,currentCooldown()>0&&q.action==='equip-apply'?'冷却剩余18秒':q.label,'primary',disabled)}${control('equip-compare',state.candidate?'查看购级':'更换候选')}</div>`;
  }
  if(state.module==='reactor') {
    const next=reactorNextCommand(),before=effectSnapshots[state.actual.join()],after=next?effectSnapshots[next.next.join()]:before;
    const names=['武器','防御','熔炼','凝聚'];
    return `<div class="dock-summary"><b>核心 Lv.1 · ${next?'本次仅调整'+names[next.index]:'当前分配已生效'}</b><span>${next?names[next.index]+' '+next.current+' → '+next.target:'手动 '+state.actual.slice(0,3).join('/')} · 免费10保持</span><span>本步：攻击 ${before?.attack||'—'} → ${after?.attack||'待预览'} / 熔炼 ${before?.income||'—'} → ${after?.income||'待预览'} · 费用0</span></div><div class="dock-buttons">${control('reactor-apply',next?'应用'+names[next.index]+next.target:'分配已生效','primary',!next||!after)}${control('reactor-reset','还原')}</div>`;
  }

  if(state.module==='planet') return `<div class="dock-summary"><b>起源星 · 轨道船坞</b><span>${planetStatus[state.planet][0]} · ${planetStatus[state.planet][1]} · 施工${crewCount('planet-build')}/2</span><span>${state.planet==='ready'?'本次领取：设施收益计入累计Buff':'当前施工与探索分开，未领收益不生效'}</span></div><div class="dock-buttons">${state.planet==='ready'?control('planet-claim','领取设施收益','primary'):control('planet-crew','调整施工人员','primary')}</div>`;
  if(state.module==='galaxy') return `<div class="dock-summary"><b>曙光星系 · 外环平台</b><span>${galaxyStatus[state.galaxy][0]} · ${galaxyStatus[state.galaxy][1]}</span><span>人员${crewCount('galaxy')} · 完成自动生效</span></div><div class="dock-buttons">${control('galaxy-crew','调整星系人员','primary')}${control('galaxy-effects','当前 / 升级效果')}</div>`;
  return '';
}
function render() {
  if(renderedRoute===state.route && !renderedCollapsed && !state.collapsed) rememberScroll();
  document.body.classList.toggle('work-family',state.family==='work');
  document.body.classList.toggle('collapsed',state.collapsed);
  document.querySelectorAll('[data-family]').forEach(button=>button.classList.toggle('active',button.dataset.family===state.family));
  $('#nav').innerHTML=nav(); $('#collapse').textContent=state.collapsed?'展开工作区':'收起工作区'; $('#pause').textContent=state.paused?'▶ 继续':'Ⅱ 暂停';
  let body=state.module==='catalog'?catalog():({reactor,equipment,planet,galaxy,research,crew,hyperspace,settings}[state.module]||overview)();
  if(state.collapsed) body=`<div class="resting"><div class="rest-icon">◈</div><h1>远航仍在继续</h1><p>当前对象与草稿保持。</p>${control('expand','继续当前工作','primary')}</div>`;
  else if(state.family==='work'&&state.module!=='catalog') body=workWrapper(body);
  $('#work-content').innerHTML=body;
  $('#action-dock')?.remove();
  const actions=dock();
  if(actions) {const element=document.createElement('div');element.id='action-dock';element.innerHTML=actions;$('#workspace').append(element);}
  $('#notice').textContent=state.notice;
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
  if(crewCount('planet-build')===0&&state.planet==='building') state.planet='paused';
  if(crewCount('planet-build')>0&&state.planet==='paused') state.planet='building';
}
function validAmountDraft(text) {return /^\d+$/.test(text.trim());}
function action(a) {
  if(a.startsWith('plus-')||a.startsWith('minus-')) {const i=Number(a.split('-')[1]);state.alloc[i]=Math.max(0,state.alloc[i]+(a.startsWith('plus')?5:-5));state.reactorError='';notify('分配草稿已修改，当前实际供能保持');}
  else if(a.startsWith('reactor-amount-')&&a!=='reactor-amount-apply'){state.reactorEditIndex=Number(a.split('-')[2]);openDetail('设置设备分配目标',`当前手动值 ${state.actual[state.reactorEditIndex]}。<label>目标金额 <input id="reactor-amount-input" value="${state.alloc[state.reactorEditIndex]}"></label><button data-action="reactor-amount-apply" class="primary">保留为分配草稿</button>`);return;}
  else if(a==='reactor-amount-apply'){const value=$('#reactor-amount-input').value;if(validAmountDraft(value)&&Number(value)<=100){state.alloc[state.reactorEditIndex]=Number(value);$('#inspect-detail').close();notify('设备目标已保留为草稿，尚未应用');}else{notify('当前示例额度内无法接纳此目标，实际分配不变');return;}}
  else if(a==='reactor-task') {state.alloc=[60,35,5,0];state.reactorError='';notify('调配方案已展开：武器增加15，防御保持，熔炼减少15');}
  else if(a==='reactor-apply') {const next=reactorNextCommand();if(sum(state.alloc)>100)state.reactorError='超过手动预算，未应用，原供能保持。';else if(next&&effectSnapshots[next.next.join()]){state.actual=next.next;notify(changed()?'本设备已应用；其余分配意图尚未提交。':'全部分配意图已逐项应用，设备工作状态更新');}}
  else if(a==='reactor-reset') {state.alloc=[...state.actual];state.reactorError='';}
  else if(a==='reactor-equal') {state.alloc=state.reactor==='opened'?[25,25,25,25]:[34,33,33,0];notify('均分草稿已准备，效果预览尚未取得');}
  else if(a==='reactor-clear') {state.alloc=[0,0,0,0];notify('清零草稿已准备，免费供能保留');}
  else if(a==='equip-compare') {state.candidate=!state.candidate;state.equipmentMode='one';if(state.equipment==='compare')state.equipment='normal';}
  else if(a==='equip-mode') {state.candidate=false;state.equipmentMode=state.equipmentMode==='max'?'one':'max';}
  else if(a==='equip-apply') {state.attributes[state.slot]=equipmentQuote().next;state.fitKeys[state.slot]=candidateType();state.fits[state.slot]=equipmentNames[state.fitKeys[state.slot]];state.cooldowns[state.slot]=18;state.equipment='normal';state.candidate=false;notify('更换成功，当前槽位与比较保留；换装冷却18秒');}
  else if(a==='equip-buy') {state.attributes[state.slot]=equipmentQuote().next;state.levels[state.slot]+=state.equipmentMode==='max'?4:state.equipmentMode==='ten'?10:1;notify('已购级，当前槽位和操作模式保持');}
  else if(a==='planet-claim') {state.planet='owned';notify('轨道船坞已领取，累计Buff更新');}
  else if(a==='planet-crew') {state.crewDraft='planet-build';goRoute('crew');return;}
  else if(a==='planet-auto') {state.planetAuto=!state.planetAuto;notify(state.planetAuto?'自动探索已开启':'本次探索完成后停止');}
  else if(a==='planet-cancel') {openDetail('立即取消探索','取消当前探索与关闭自动不同。当前施工与待领设施保持原状态。');return;}
  else if(a==='planet-buff') {goRoute('settings/danger/reforge');return;}
  else if(a==='galaxy-crew') {state.crewDraft='galaxy';goRoute('crew');return;}
  else if(a==='crew-apply') {state.crewMembers[state.crewId].job=state.crewDraft;syncDemoCrewTargets();notify('派遣已生效，人物与目标人数同步');}
  else if(a==='crew-release') {if(state.onlineTask.crewId===state.crewId&&['running','ready'].includes(state.onlineTask.status)){openDetail('当前成员被任务保留','先停止自动任务或解决待领回执，再释放当前人员。');return;}state.crewMembers[state.crewId].job='idle';syncDemoCrewTargets();notify('当前成员已释放，目标人数与缺人暂停状态更新');}
  else if(a==='crew-target') {goRoute(state.crewDraft==='galaxy'?'galaxy':state.crewDraft==='hyperspace'?'hyperspace/routes':'planet');return;}
  else if(a==='research-apply-iron'||a==='research-apply-uranium') {const iron=a==='research-apply-iron';const draft=iron?state.researchDraft:state.researchUraniumDraft;if(!validAmountDraft(draft)){state.researchError=(iron?'铁':'铀')+'投入需为非负整数金额；当前生效值保持，草稿可继续修正。';}else{if(iron)state.researchBudget=state.researchDraft;else state.researchUranium=state.researchUraniumDraft;state.researchError='';state.researchFeedback=(iron?'铁':'铀')+'投入已应用，另一资源与研究工作量保持。';notify('本资源投入已应用');}}

  else if(a==='research-select') {state.researchDrawer=true;}
  else if(a==='research-close') {state.researchDrawer=false;}
  else if(a==='research-reset') {state.researchDraft=state.researchBudget;state.researchUraniumDraft=state.researchUranium;state.researchError='';state.researchFeedback='草稿已还原为当前生效值。';}
  else if(a==='research-auto-apply') {state.researchAuto=state.researchAutoDraft;state.researchRatio=state.researchRatioDraft;state.researchFeedback='预算设置已生效，下一个60游戏秒刷新点采用；当前投入金额尚未重算。';}
  else if(a==='research-crew') {state.crewDraft='research';goRoute('crew');return;}
  else if(a==='equip-one'||a==='equip-ten'||a==='equip-max-mode') {state.equipmentMode=a==='equip-one'?'one':a==='equip-ten'?'ten':'max';state.candidate=false;}
  else if(a==='hyper-manual') {goRoute('hyperspace/manual');return;}
  else if(a==='manual-start') {if(!['running','ready'].includes(state.manualTask.status)){state.manualTask={status:'running',route:state.routeId,run:'manual-02',receipt:null};notify('手动挑战已开始，在线任务保持');}goRoute('hyperspace/routes');return;}
  else if(a==='online-start') {if(!['running','ready'].includes(state.onlineTask.status)){state.onlineTask={status:'running',route:state.routeId,run:'online-02',receipt:null,mode:'single',crewId:null};notify('单次挂机已开始，手动挑战保持');}}
  else if(a==='online-auto') {const task=state.onlineTask;if(task.status==='running'&&task.mode==='auto'){if(task.crewId&&state.crewMembers[task.crewId]?.job==='hyperspace')state.crewMembers[task.crewId].job='idle';state.onlineTask={...task,status:'idle',crewId:null};syncDemoCrewTargets();notify('自动任务已停止，Started任务不生成奖励');}else if(task.status==='ready'){goRoute('hyperspace/receipt/online');return;}else{const crewId=Object.keys(state.crewMembers).find(id=>state.crewMembers[id].job==='hyperspace');if(!crewId){state.crewDraft='hyperspace';goRoute('crew');notify('请选择并派驻在线挂机人员，当前任务尚未开始');return;}state.onlineTask={status:'running',route:state.routeId,run:'online-auto-02',receipt:null,mode:'auto',crewId};notify('自动挂机已开始，路线与人员快照绑定本任务');}}
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
  else if(a.startsWith('danger-')&&['reforge','import','new'].includes(a.slice(7))) {const kind=a.slice(7);state.dangerKind=kind;state.dangerSource=kind==='reforge'?'起源星':kind==='import'?'backup-02.json':'D:/SpaceIdle/save';state.dangerPreview=null;state.dangerResult=null;goRoute('settings/danger/'+kind);return;}
  else if(a==='danger-preview') {state.dangerPreview={kind:state.dangerKind,source:state.dangerSource,droneId:state.droneId};state.dangerResult=null;}
  else if(a==='danger-confirm') {const preview=state.dangerPreview;if(preview&&preview.kind===state.dangerKind&&preview.source===state.dangerSource&&preview.droneId===state.droneId){state.dangerResult=`${{reforge:'重铸',import:'导入',new:'新游戏'}[preview.kind]}已完成：${preview.source}；实际结果摘要保留。`;state.dangerPreview=null;notify('本次操作完成，重复确认已关闭');}}
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
  const button=event.target.closest('[data-family],[data-module],[data-group],[data-slot],[data-action],[data-route],[data-context-route],[data-crew],[data-drone],[data-hyper-route],[data-study]');
  if(!button) return;
  if(button.dataset.family) {rememberScroll();state.family=button.dataset.family;render();}
  else if(button.dataset.module) setModule(button.dataset.module);
  else if(button.dataset.group) switchGroup(button.dataset.group);
  else if(button.dataset.slot!==undefined) {state.slot=Number(button.dataset.slot);state.candidate=false;render();}
  else if(button.dataset.route) goRoute(button.dataset.route);
  else if(button.dataset.contextRoute) {const target=button.dataset.contextRoute;if(target==='crew'&&state.group==='hyperspace'&&state.onlineTask.crewId){state.crewId=state.onlineTask.crewId;state.crewDraft=state.crewMembers[state.crewId].job;}goRoute(target.includes('/')?target:(state.moduleLast[target]||target));}
  else if(button.dataset.crew) {state.crewId=button.dataset.crew;state.crewDraft=state.crewMembers[state.crewId].job;render();}
  else if(button.dataset.drone) {state.droneId=button.dataset.drone;state.formationPreview=null;invalidateForge();state.dangerPreview=null;notify('已更换无人机对象，需要重新预览');render();}
  else if(button.dataset.hyperRoute) {state.routeId=button.dataset.hyperRoute;render();}
  else if(button.dataset.study) {state.researchId=button.dataset.study;state.researchDrawer=false;state.researchState='running';state.researchFeedback='已切换设备，原研究工作量保留。';render();}
  else action(button.dataset.action);
});
document.addEventListener('input',event=>{
  if(event.target.id==='research-budget') state.researchDraft=event.target.value;
  if(event.target.id==='research-uranium')state.researchUraniumDraft=event.target.value;
  if(event.target.id==='research-ratio')state.researchRatioDraft=event.target.value;
  if(event.target.id==='danger-source') {state.dangerSource=event.target.value;state.dangerPreview=null;state.dangerResult=null;const preview=$('.transaction-preview');if(preview)preview.remove();notify('来源已改变，旧预览失效');}
  if(event.target.id==='material-amount') state.materialDraft=event.target.value;
  if(event.target.id==='filter-source') state.importFilterText=event.target.value;
  if(['research-budget','research-uranium'].includes(event.target.id)){const dirty=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium;const flag=$('.investment-title small');if(flag)flag.textContent=dirty?'草稿未应用，当前生效值保持':'当前投入已生效';const context=$('[data-context-route="research"] span');if(context)context.textContent=summary('research');}
});
document.addEventListener('change',event=>{
  const id=event.target.id,value=event.target.value;
  if(id==='research-auto-toggle')state.researchAutoDraft=event.target.checked;
  if(id==='crew-target') {state.crewDraft=value;render();}
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
  state[key]=event.target.value;
  if(key==='reactor') {state.actual=event.target.value==='idle'?[0,0,0,0]:[45,35,20,0];state.alloc=event.target.value==='draft'?[60,35,5,0]:event.target.value==='rejected'?[55,35,20,0]:[...state.actual];state.reactorError=event.target.value==='rejected'?'额度不足，实际供能保持原值。':'';}
  if(key==='equipment'){state.candidate=event.target.value==='compare';state.cooldowns=event.target.value==='cooldown'?{[state.slot]:18}:{};if(event.target.value==='cooldown')state.equipment='normal';}
  render();
};
for(const kind of ['manual','online']) $('#'+kind+'-task-case').onchange=event=>{const key=kind==='manual'?'manualTask':'onlineTask';state[key]={...state[key],status:event.target.value,route:kind==='manual'?'pulse':'missile'};render();};
$('#research-case').onchange=event=>{state.researchState=event.target.value;render();};
$('#research-unlocks').onchange=event=>{state.researchUnlocked=event.target.value==='all'?Object.keys(studies):['equipment_finishing','uranium_extraction','weapon_accuracy','equipment_reinforcement','resource_refining','singularity'];if(!state.researchUnlocked.includes(state.researchId))state.researchId=state.researchUnlocked[0];render();};
document.addEventListener('visibilitychange',()=>document.body.classList.toggle('page-hidden',document.hidden));
window.addEventListener('resize',fitBattle);
window.G1={state,render,setModule,setRoute:goRoute,fitBattle,summary};
render();
