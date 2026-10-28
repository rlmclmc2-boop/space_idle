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
  alloc: [45,35,20,0], actual: [45,35,20,0], reactorError: '', reactorReceipt: '', reactorFailAt: -1, reactorLastPlan: null, reactorIntent: 'custom',
  slot:0, fitKeys:['laser','missile','longLaser','shield','armour'], levels: [24,18,18,18,18], fits: ['脉冲炮','舰载导弹','长激光','护盾发生器','装甲'],
  attributes:['12.4 K','12.4 K','12.4 K','84.0 K','84.0 K'], candidate: false, equipmentMode: 'one', planetAuto: true, planetId: '1', galaxyNode: '9', galaxyNodes:structuredClone(ColonyModels.galaxy.nodes), galaxyView:{x:0,y:-55,zoom:1.3}, planets: structuredClone(ColonyModels.planets), crewPlanet:'1', crewFacility:'shipyard', crewMode:'1', crewError:'',
  crewId: 'navigator', crewDraft: 'planet-build',
  crewMembers: structuredClone(ColonyModels.crew),
  researchId:'equipment_finishing', researchBudget:'800000', researchDraft:'800000', researchUranium:'120000', researchUraniumDraft:'120000', researchAuto:false, researchRatio:'25', researchAutoDraft:false, researchRatioDraft:'25', researchState:'running', researchDrawer:false, researchUnlocked:['equipment_finishing','uranium_extraction','weapon_accuracy','equipment_reinforcement','resource_refining','singularity'], researchError:'', researchFeedback:'', researchIntent:25, researchMode:'once', researchCustom:false, researchModeRatios:{once:25,follow:25}, cooldowns:{},
  droneId: 'd2', droneSelection: ['d2'], equippedDrones: ['d1'], formationDraft: ['d2'], formationPreview: null,
  forgePreview: null, forgeResult: null, forgeOperation: 'reroll',
  materialDraft: '100', materialReceipt: '', routeId:'pulse', manualTask:{status:'idle',route:'pulse',run:'manual-01',receipt:null}, onlineTask:{status:'idle',route:'missile',run:'online-01',receipt:null,mode:'single',crewId:null},
  dangerKind: 'reforge', dangerSource: '起源星', dangerPreview: null, dangerResult: null,
  enhance:{paid:27,extra:3,effective:30,weapon:['proficiency','repeat','critical'],defence:['adaptation','memory','deferred'],branches:{proficiency:['A','B','A'],repeat:['A','B',''],critical:['B','',''],adaptation:['A','B',''],memory:['B','A',''],deferred:['B','','']},effect:'proficiency',node:0,choice:'',purchaseMode:'one',funds:false,feedback:'',quoteUsed:false,receipt:null},
  maintenance:{save:'saved',directory:'D:/SpaceIdle/save',directoryDraft:'D:/SpaceIdle/save',music:true,effects:true,damage:'all',interval:'60',skip:false,feedback:'',dangerError:'',importSource:'backup-02.json',newDirectory:'D:/SpaceIdle/new-voyage',clearSettings:false,retained:['d2'],previewSerial:0},
  archive:{tab:'tutorial',tutorial:'equip',completed:['equip','pickup'],guidePaused:false,enemy:'enemy-demo-1',notifications:[{key:'unlock:crew_06',title:'船员开放 · 无限大',seen:false,read:false},{key:'research:equipment_finishing',title:'精密制造研究完成',seen:false,read:false}],intel:[{id:'enemy-demo-1',name:'哨戒舰',tier:'普通',visual_key:'enemy_opening_sentry',texture:'ships/enemy/fleet_20261019/sentry.png',armour:'12.0 K',shield:'0',mechanics:'当前护盾已耗尽；装甲仍可承伤。'},{id:'enemy-demo-2',name:'护盾舰',tier:'精英',visual_key:'enemy_opening_shielded_elite',texture:'ships/enemy/elite_boss_20261020/shielded-elite.png',armour:'28.0 K',shield:'16.0 K',mechanics:'护盾与装甲分别承伤；护盾耗尽后余伤进入装甲。'}]},
  notice: '舰桥就绪'
};
const groups = {
  combat: {name:'战力维护', roots:['equipment','reactor','research','enhancement'], cards:[['equipment','配装'],['reactor','供能'],['research','科研']]},
  colony: {name:'殖民推进', roots:['crew','planet','galaxy'], cards:[['crew','人员'],['planet','星球'],['galaxy','星系']]},
  hyperspace: {name:'超空间收获', roots:['hyperspace','crew'], cards:[['hyperspace/routes','任务'],['hyperspace/formation','无人机编队'],['crew','人员']]},
  maintenance: {name:'航行维护', roots:['settings','archive'], cards:[['settings/save','保存'],['settings/danger/reforge','危险事务'],['archive','档案']]}
};
const drones = {
  d1: {name:'巡航者·脉冲', weapon:'脉冲炮', quality:'史诗', level:24, affix:'攻击 +8%', icon:'pulse.png'},
  d2: {name:'猎隼·导弹', weapon:'导弹', quality:'稀有', level:18, affix:'暴击 +4%', icon:'missile.png'},
  d3: {name:'棱镜·光束', weapon:'长激光', quality:'史诗', level:20, affix:'射速 +6%', icon:'beam.png'}
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
function memberJob(m){if(m.job==='hyperspace')return '在线自动挂机 · '+(m.targetRoute?routeName(m.targetRoute):'目标待读取');if(m.job.startsWith('planet-')){const p=state.planets.find(p=>p.id===m.targetPlanet);return p.name+' / '+(m.job==='planet-build'?p.facilities[m.targetFacility].name+'施工':'探索');}return jobs[m.job];}
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
  return `<div class="pagehead"><div><span class="eyebrow">${en}</span><h1>${title}</h1>${sub?`<div class="sub">${sub}</div>`:''}</div>${tag}</div>`;
}
function nav() {
  if(state.family==='scene') return modules.map(([id,name])=>`<button data-module="${id}" class="${state.module===id?'active':''}">${name}</button>`).join('');
  return Object.entries(groups).map(([id,g])=>`<button data-group="${id}" class="${state.group===id?'active':''}">${g.name}</button>`).join('')+control('catalog','全系统索引');
}
function summary(route) {
  if(route==='equipment') {EquipmentWorkbench.ensure(state);return EquipmentWorkbench.ship(state).name+' · '+EquipmentWorkbench.slot(state.slot).label+' / '+state.fits[state.slot]+' Lv.'+state.levels[state.slot]+(state.candidate?' / 有候选':'');}
  if(route==='reactor') return `${sum(state.actual)}/100${changed()?' · 草稿'+sum(state.alloc):' · 已生效'}`;
  if(route==='research') return `${studies[state.researchId].name} · 铁${amountDisplay(state.researchBudget)}/秒${state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium?' / 有草稿':''}`;
  if(route==='crew') {if(state.group==='hyperspace'){const task=state.onlineTask,held=state.hyperspaceTaskDesk?state.hyperspaceTaskDesk.autoEnabled&&state.hyperspaceTaskDesk.autoCrew:task.crewId;return held?state.crewMembers[held].name+' · '+routeName(task.route)+' / '+taskStatus(task):'当前在线任务无保留船员';}const m=state.crewMembers[state.crewId];return `${m.name} · ${memberJob(m)}`;}
  if(route==='planet') return `${selectedPlanet().name} · ${selectedFacility().name} / ${facilityStatus(selectedPlanet(),selectedFacility())}`;
  if(route==='galaxy'){const n=state.galaxyNodes[state.galaxyNode];return `${galaxyName(n)} · ${galaxyWorkStatus(n)}`;}
  if(route==='hyperspace/routes') return `手动·${routeName(state.manualTask.route)} ${taskStatus(state.manualTask)} / 挂机·${routeName(state.onlineTask.route)} ${taskStatus(state.onlineTask)}`;
  if(route==='hyperspace/formation') return `${state.equippedDrones.map(id=>drones[id].name).join(' / ')}${state.formationDraft.join()!==state.equippedDrones.join()?' · 有候选':''}`;
  if(route==='settings/danger/reforge') return dangerMatches(state.dangerPreview,'reforge',selectedPlanet().name)?'重铸预览待确认':dangerMatches(state.dangerResult,'reforge',selectedPlanet().name)?'最近重铸结果可查':'重铸 / 导入 / 新游戏';
  if(route==='archive') return ({tutorial:'飞行手册',intel:'当前敌情',notifications:'通知档案',statistics:'伤害明细'})[state.archive.tab]+' · 未读'+state.archive.notifications.filter(n=>!n.read).length;
  if(route==='settings'||route==='settings/save') return MaintenanceModels.saveStates[state.maintenance.save].title;
  return '敌情 / 通知 / 教程';
}
function workWrapper(body) {
  const g=groups[state.group];
  return `<div class="context-strip" aria-label="关联作业">${g.cards.map(([route,title])=>`<button class="context-object ${state.route===route||(!route.includes('/')&&state.module===route&&!(route==='settings'&&state.route.includes('/danger/')))?'active':''}" data-context-route="${route}" title="${escapeText(summary(route))}"><b>${title}</b><span>${summary(route)}</span></button>`).join('')}</div><section class="work-sheet">${body}</section>`;
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
    `<details class="allocation-presets"><summary>调配预设（可选）</summary>${control('reactor-task','示例：保持防御，武器优先')}</details>`+
    `<div class="reactor-room"><div class="reactor-grid reactor-room-grid"><svg class="reactor-pipes ${!state.paused&&sum(state.actual)>0?'running':''}" aria-label="核心出口、主管、设备入口统一连接"></svg>${machine(0)}${machine(2)}<div class="reactor-core-assembly ${sum(state.actual)+free>0&&!state.paused?'running':''}"><img src="${SceneModels.reactor.core.path}" alt="反应炉独立核心"><div class="reactor-energy"></div><div class="core-instrument"><small>当前有效供能</small><b>${sum(state.actual)+free}</b></div></div>${machine(1)}${opened?machine(3):''}<span class="trunk-label">供能主管</span></div></div>`+
    (state.reactorReceipt?`<div class="note">${state.reactorReceipt}</div>`:'')+
    (state.reactorError||sum(state.alloc)>100?`<div class="note bad">${state.reactorError||'草稿超过手动预算，当前实际供能不变。'}</div>`:'')+
    `<div class="secondary-actions">${control('reactor-equal','均分')}${control('reactor-clear','清零草稿')}${control('reactor-buy','核心升级 · 10 铀','quiet')}</div>`;
}

const equipmentNames={laser:'脉冲炮',missile:'舰载导弹',longLaser:'长激光',cannon:'舰炮',shield:'护盾发生器',armour:'装甲'};
const equipmentCycles={laser:'0.8秒',missile:'1.2秒',longLaser:'持续光束',cannon:'1.4秒'};
function candidateType(){return EquipmentWorkbench.isWeapon(state.slot)?(state.fitKeys[state.slot]==='cannon'?'laser':'cannon'):(state.fitKeys[state.slot]==='shield'?'armour':'shield');}
function slotIcon(){return 'cartoon_'+state.fitKeys[state.slot]+'.svg';}
function comparisonCycle(){const current=equipmentCycles[state.fitKeys[state.slot]]||'无装备';return EquipmentWorkbench.isWeapon(state.slot)?'配置周期 '+current+(state.candidate?' → '+equipmentCycles[candidateType()]:'（保持）'):'防御类型 '+(equipmentNames[state.fitKeys[state.slot]]||'空槽')+(state.candidate?' → '+equipmentNames[candidateType()]:'（保持）');}
function currentCooldown() {return state.cooldowns[state.slot]||0;}
function equipmentQuote(){return EquipmentWorkbench.singleQuote(state);}
function equipment() {return EquipmentWorkbench.render(state,control,asset,moduleHead);}

function loadPlanetFixture(stage){
  const key=selectedPlanet().id+'/'+selectedFacility().id+'/'+stage;
  const response=ColonyModels.planetStageResponses[key];
  if(!response){notify('当前星球/设施尚未提供此完整情境响应，实际对象保持。');return false;}
  state.planets=state.planets.map(p=>p.id===response.planet.id?structuredClone(response.planet):p);
  state.crewMembers=structuredClone(response.crewMembers);state.planet=response.stage;
  return true;
}
function facilityStatus(p,f){if(f.state==='building'){if(!p.running)return '缺少进行中的探索';if(f.extraCrew&&crewCount('planet-build',p.id,f.id)<f.extraCrew)return '缺少额外施工人员';return '施工中';}return {locked:'未达探索门槛',ready:'待领取',owned:'已领取 · 收益生效'}[f.state];}
function planet() {
  const p=selectedPlanet(),f=selectedFacility(),pct=Math.round(f.work/f.required*100),status=facilityStatus(p,f);
  return moduleHead(p.name,'探索度 '+p.exploration,`<select id="planet-select" aria-label="选择星球">${state.planets.filter(p=>p.available).map(p=>`<option value="${p.id}" ${p.id===state.planetId?'selected':''}>${p.name}</option>`).join('')}</select>`)+
    `<div class="orbital-room"><div class="orbital-stage ${p.running?'exploring':'stopped'} ${p.stellar?'stellar':''}"><div class="orbital-ellipse"></div><div class="planet-globe" style="--planet-size:${Math.min(p.radiusScale,1.22)*230}px;--atmosphere:#${p.atmosphere}"><img src="${p.surface.replace('res://assets/',asset)}" alt="${p.name}">${p.cloudOpacity?`<img class="cloud-layer" style="opacity:${p.cloudOpacity}" src="${p.cloud.replace('res://assets/',asset)}" alt="独立云层">`:''}</div>${p.running?`<img class="orbital-scout" src="${asset}planets/orbital/scout-v1.png" alt="正在探索的探索机">`:''}${Object.values(p.facilities).map((x,i)=>`<button data-facility="${x.id}" class="orbit-facility orbit-position-${i} ${x.state} ${x.id===f.id?'selected':''}"><img src="${x.icon.replace('assets/',asset)}" alt=""><span class="orbit-facility-label"><b>${x.name}</b><small>${facilityStatus(p,x)}</small></span></button>`).join('')}<div class="exploration-readout"><b>${p.running?'本次探索 '+p.elapsed+' / '+p.duration+' 游戏秒':'探索已停止'}</b><span>探索人员 ${crewCount('planet-explore',p.id)} / 1 · ${p.automatic?'完成后继续':'本次完成后停止'}</span></div></div><div class="facility-console"><span class="eyebrow">ORBITAL DEVELOPMENT</span><h2>${f.name}</h2><span class="pill ${status==='施工中'||f.state==='owned'?'good':'warn'}">${status}</span><div class="facility-work"><b>${f.work} <small>/ ${f.required}次</small></b><div class="meter"><i style="width:${pct}%"></i></div></div><dl><dt>探索门槛</dt><dd>${f.threshold} / 当前${p.exploration}</dd><dt>${['ready','owned'].includes(f.state)?'施工人员':'额外施工人员'}</dt><dd>${['ready','owned'].includes(f.state)?(crewCount('planet-build',p.id,f.id)?crewCount('planet-build',p.id,f.id)+'人仍占用 · 待同步':'0人 · 已释放'):crewCount('planet-build',p.id,f.id)+' / '+f.extraCrew}</dd><dt>${f.state==='owned'?'当前收益':'领取后收益'}</dt><dd>${f.effectSummary}</dd></dl>${f.state==='ready'?'<p class="sub">当前收益尚未计入；领取后生效。</p>':''}<details class="technical-details facility-rules"><summary>建设与领取规则</summary><p>达到探索门槛后进入施工。后续探索完成、人员满足时推进施工；完成后释放施工人员，领取后才计入收益。</p></details>${control('planet-explorer','查看探索人员','quiet')}</div></div><div class="secondary-actions">${control('planet-auto',p.automatic?'本次完成后停止':'开启自动探索','',!p.running)}${control('planet-cancel','立即取消探索','danger',!p.running)}${control('planet-buff','累计Buff / 重铸')}</div>`;
}
const galaxyPoint=n=>({x:400+(n.x-n.z)*2.3,y:270+(n.x+n.z)*1.1});
const galaxyEffect={colony_ring:'船员经验贡献',orbital_shipyard:'装备普通属性贡献',stellar_energy_array:'反应炉容量贡献',interstellar_refinery:'铁自动收入比例',crystal_refinery:'直接碎片贡献',heavy_element_refinery:'铀自动收入比例'};
const galaxyName=n=>n.state==='fog'?'未探索节点':n.name;
const galaxyWorkStatus=n=>!crewCount('galaxy')&&['building','upgrading','planned'].includes(n.state)?'缺人停工 · 进度保留':galaxyStatus[n.state][0];
function galaxyArt(family,level,cls=''){
 const file=family+(level?'-lv'+level:'')+'.png',r=SceneModels.galaxyBounds[file];
 return `<svg class="${cls}" viewBox="${r.join(' ')}" aria-hidden="true"><image href="art/galaxy/${file}" width="384" height="384"/></svg>`;
}
function focusGalaxy(){const q=galaxyPoint(state.galaxyNodes[state.galaxyNode]);state.galaxyView={x:(400-q.x)*1.75,y:(270-q.y)*1.75,zoom:1.75};}
function galaxy() {
 const n=state.galaxyNodes[state.galaxyNode],view=state.galaxyView,workers=crewCount('galaxy');
 const point=id=>id==='hub'?{x:400,y:270}:galaxyPoint(state.galaxyNodes[id]);
 const detail=n.state==='fog'?'<div class="unknown-site">?</div><p>父节点达到可达条件后揭示。设施类型与效果保持隐藏。</p>':`<div class="city-node-progress"><b>${n.progress}%</b><span>${n.state==='upgrading'?'当前Lv.'+n.level+'仍贡献，目标Lv.'+n.targetLevel:n.state==='complete'?'已生效 · 无需领取':n.state==='planned'?'已可达，等待自动工程调度':'建设工作已完成 '+n.progress+'%'}</span></div><div class="meter"><i style="width:${n.progress}%"></i></div><dl class="city-facts"><dt>工程人员</dt><dd>${workers} / 6</dd><dt>当前贡献</dt><dd>${n.state==='complete'||n.state==='upgrading'?galaxyEffect[n.family]+' · Lv.'+n.level:'尚未生效'}</dd><dt>完成后</dt><dd>${galaxyEffect[n.family]} · Lv.${n.state==='upgrading'?n.targetLevel:n.level}</dd></dl><small>${n.state==='upgrading'?'升级中保留当前级贡献。':n.state==='complete'?'当前级贡献已被接纳。':'施工完成后自动生效，无需领取。'}</small>`;
 return moduleHead('第一星系','区域一',`<span class="pill ${workers?'':'warn'}">工程人员 ${workers} / 6</span>`)+`<div class="city-room"><div class="city-map" tabindex="0" aria-label="星系地图，可平移缩放"><svg viewBox="0 0 800 550"><defs><pattern id="city-grid" width="45" height="24" patternUnits="userSpaceOnUse"><path d="M0 12L22.5 0L45 12L22.5 24Z" fill="none" stroke="#b8c9bd" stroke-width=".5"/></pattern></defs><rect width="800" height="550" fill="url(#city-grid)"/><g id="city-transform" transform="translate(${view.x} ${view.y}) translate(400 270) scale(${view.zoom}) translate(-400 -270)">${ColonyModels.galaxy.links.map(([a,b])=>{const x=point(a),y=point(b);return `<path d="M${x.x} ${x.y}L${y.x} ${y.y}" stroke="#aabdb0" stroke-width="8"/><path d="M${x.x} ${x.y}L${y.x} ${y.y}" stroke="#e1e4d8" stroke-width="4"/>`;}).join('')}<svg x="350" y="205" width="100" height="85">${galaxyArt('galaxy_core',0)}</svg>${Object.values(state.galaxyNodes).sort((a,b)=>galaxyPoint(a).y-galaxyPoint(b).y).map(x=>{const q=galaxyPoint(x);return `<g data-galaxy-node="${x.id}" class="city-node ${x.state} ${x.id===n.id?'selected':''}" transform="translate(${q.x} ${q.y})" aria-label="${galaxyName(x)}"><ellipse class="city-platform" cx="0" cy="0" rx="37" ry="17"/>${x.id===n.id?'<ellipse class="city-selected-orbit" cx="0" cy="0" rx="44" ry="22"/>':''}${x.state==='fog'?'<text y="4" text-anchor="middle" class="fog-mark">?</text>':x.state==='planned'?'<path d="M-24 0L0 -12L24 0L0 12Z" fill="none" stroke="#85a59a" stroke-dasharray="3 3"/>':`<svg x="-36" y="-52" width="72" height="65" ${x.state==='building'?'opacity=".65"':''}>${galaxyArt(x.family,x.level)}</svg>`}${x.state==='building'||x.state==='upgrading'?`<rect x="-27" y="18" width="54" height="3" fill="#c6cec1"/><rect x="-27" y="18" width="${54*x.progress/100}" height="3" fill="${workers?'#4d9989':'#bf8e56'}"/>`:''}<text class="city-node-label" y="${x.id===n.id?45:37}" text-anchor="middle">${x.state==='fog'?'未探索':x.name.split(' ')[0]+' · '+(x.state==='planned'?'地基':'Lv.'+x.level)}</text></g>`;}).join('')}<image href="art/galaxy/transport_shuttle.png" x="386" y="326" width="40" height="40" class="city-shuttle"/></g></svg><div class="city-map-tools">${control('galaxy-zoom-out','−')}${control('galaxy-reset','所选')}${control('galaxy-overview','总览')}${control('galaxy-zoom-in','＋')}</div></div><div class="city-console"><div class="city-selection-identity"><small>地图所选 · ${n.id}</small><h2>${galaxyName(n)}</h2><span class="pill ${n.state==='complete'?'good':'warn'}">${galaxyWorkStatus(n)}</span></div><div class="city-selection-facts">${detail}</div></div></div><div class="secondary-actions">${control('galaxy-region','区域与发展汇总')}${control('galaxy-effects','当前节点效果明细')}</div>`;
}
// Mock Amount boundary: fixture income is canonical integer text; no research speed formula.
const budgetIncome={iron:'3200000',uranium:'480000'};
const budgetWallet={iron:'128600000',uranium:'8400000'};
function budgetPreview(ratio,automatic=false){
 const response=BudgetResponseFixtures[String(Math.round(ratio*10))],valid=Number.isFinite(ratio)&&ratio>=0&&ratio<=100&&Math.abs(ratio*10-Math.round(ratio*10))<1e-7&&(!automatic||ratio>=0.1)&&response;
 return ['iron','uranium'].map((id,i)=>({id,rate:valid?response[i][0]:null,left:valid?response[i][1]:null,reserve:valid?response[i][2]:null}));
}
function amountDisplay(text){return SceneModels.amountDisplays?.[text]|| (String(text).length>18?'金额显示待更新':String(text));}
function researchBenefitText(){return ({equipment_finishing:'武器与防御普通值 ×1.25',uranium_extraction:'原生铀收入 ×1.1',weapon_accuracy:'武器伤害 ×1.1',equipment_reinforcement:'防御普通容量 ×1.1',resource_refining:'原生铁收入 ×1.1',singularity:'AI数量 +1',fragment_condensation:'直接碎片收入 ×1.1',unification:'联合因子按收入峰值更新'})[state.researchId];}
function researchIntentPanel(){
 const once=state.researchMode==='once',rows=budgetPreview(state.researchIntent,!once);
 return `<div class="budget-intent"><div class="investment-title"><h3>科研预算</h3><span class="budget-status">${once&&state.researchCustom?'自定义金额草稿':state.researchIntent+'%比例草稿'}</span></div><div class="budget-modes">${control('research-mode-once','本次调整',once?'active':'')}${control('research-mode-follow','持续跟随收入',!once?'active':'')}</div><label>近期收入比例 <output>${state.researchIntent}%</output><input id="research-intent" type="range" min="0" max="100" step="0.1" value="${state.researchIntent}" aria-label="科研共同近期收入比例"></label><div class="budget-current-mode">当前持续跟随：${state.researchAuto?'开启 · '+state.researchRatio+'%':'关闭'}${!once?' · 沿原周期采用，当前投入不立即改变':''}</div><div class="budget-column-key">${once?'当前 → 草稿':'当前 → 按本次收入预计'} / 游戏秒</div><div class="budget-comparison">${rows.map((r,i)=>{const current=i?state.researchUranium:state.researchBudget,draft=i?state.researchUraniumDraft:state.researchDraft,target=once?draft:r.rate;return `<article><b>${i?'铀':'铁'}</b><strong title="${escapeText(current)} → ${escapeText(target)}">${amountDisplay(current)} → ${target===null?'不可应用':amountDisplay(target)}</strong><span class="budget-resource-context">收入 ${amountDisplay(budgetIncome[r.id])}/秒 · ${state.researchCustom&&once?'自定义收支与用时待预览':r.rate===null?'无合法周期目标':'结余 '+amountDisplay(r.left)+'/秒；'+(r.reserve===null?'本资源不消耗':('断流库存约'+r.reserve+'秒'))}</span>${once?control(i?'research-apply-uranium':'research-apply-iron',i?'应用铀':'应用铁','primary',draft===current):''}</article>`;}).join('')}</div>${once?`<details class="precise-investment"><summary>精确金额</summary><label>铁 / 游戏秒<input id="research-budget" value="${escapeText(state.researchDraft)}"></label><label>铀 / 游戏秒<input id="research-uranium" value="${escapeText(state.researchUraniumDraft)}"></label>${control('research-reset','还原当前投入','quiet')}</details>`:`<div class="secondary-actions">${control('research-intent-auto','应用持续比例','primary',state.researchIntent<0.1||state.researchIntent>100)}${state.researchAuto?control('research-auto-stop','关闭持续跟随'):''}</div><small>持续比例至少0.1%；关闭持续跟随保留当前投入。</small>`}<div class="budget-benefit"><b>完成收益</b><span>${researchBenefitText()}</span><small>投入改变完成用时，收益保持；目标速度/剩余时间待预览。</small></div></div>`;
}
function refreshBudgetControls(){const box=document.createElement('div');box.innerHTML=researchIntentPanel();$('.budget-intent output').textContent=state.researchIntent+'%';$('.budget-status').textContent=box.querySelector('.budget-status').textContent;$('.budget-comparison').innerHTML=box.querySelector('.budget-comparison').innerHTML;for(const [id,value] of [['research-budget',state.researchDraft],['research-uranium',state.researchUraniumDraft]]){const field=$('#'+id);if(field&&document.activeElement!==field)field.value=value;}const autoButton=$('[data-action="research-intent-auto"]');if(autoButton)autoButton.disabled=state.researchIntent<0.1||state.researchIntent>100;const context=$('[data-context-route="research"] span');if(context)context.textContent=summary('research');const pending=$('.research-budget-state');if(pending)pending.textContent=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium?'有未应用草稿':'已生效';}

function research() {
  const study=studies[state.researchId];
  const stopped=state.paused||state.researchState==='paused'||state.researchState==='completed';
  const status=state.researchState==='completed'?'本级研究完成':state.paused||state.researchState==='paused'?'暂停':state.researchState==='unfunded'?'基础研究中 · 投入加速不足':'研究中';
  const dirty=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium;
  return moduleHead('AI科技工厂',study.name+' · Lv.'+study.level,`<span class="pill ${stopped?'warn':'good'}">${status}</span>`)+
    `<div class="research-workbench"><div class="factory-room ${stopped?'stopped':'working'}"><img class="factory-background" src="${asset}ai_tech_factory/workshop-background-v2.png" alt="AI工厂场景"><img class="factory-machine" src="${asset}ai_tech_factory/${study.image}" alt="${study.name}设备"><img class="factory-probe" src="${asset}ai_tech_factory/inspection-probe-v2.png" alt="当前研究探针"><div class="research-device-status"><span class="eyebrow">CURRENT DEVICE</span><b>${study.name}</b><span>${state.researchState==='completed'?'100%':study.progress}</span><div class="meter"><i style="width:${state.researchState==='completed'?'100%':study.progress}"></i></div><small>工作量 ${state.researchState==='completed'?study.required:study.work} / ${study.required}</small><small>速度 ${study.speed}工作量 / 游戏秒</small><small>${state.researchState==='completed'?'已完成，等待选择下一研究':stopped?'暂停期间不推进':'预计剩余 '+study.remaining+'（游戏时间）'}</small><div class="budget-crew">续研岗位：${crewCount('research')?'有人 · 完成后续研':'无人 · 完成后停下'} ${control('research-crew','查看','quiet')}</div></div><button data-action="research-select" class="factory-selector">选择研究设备</button></div>`+
    `<div class="research-current-console"><div class="investment-title"><h3>当前投入</h3><span class="research-budget-state">${dirty?'有未应用草稿':'已生效'}</span></div><dl><dt>铁 / 游戏秒</dt><dd title="${escapeText(state.researchBudget)}">${amountDisplay(state.researchBudget)}</dd><dt>铀 / 游戏秒</dt><dd title="${escapeText(state.researchUranium)}">${amountDisplay(state.researchUranium)}</dd></dl><div class="current-follow-state">持续跟随 ${state.researchAuto?'开启 · '+state.researchRatio+'%':'关闭'}</div><div class="current-research-benefit"><small>完成收益</small><b>${researchBenefitText()}</b></div>${control('research-budget-open',dirty?'继续调整预算':'调整科研预算','primary')}${state.researchError?`<div class="note bad">${state.researchError}</div>`:''}${state.researchFeedback?`<div class="research-feedback">${state.researchFeedback}</div>`:''}</div><div class="investment-console ${state.researchBudgetOpen?'is-open':''}" ${state.researchBudgetOpen?'':'hidden'}><div class="budget-drawer-heading"><h2>调整科研预算</h2>${control('research-budget-close','收起预算','quiet')}</div>${researchIntentPanel()}${state.researchError?`<div class="note bad">${state.researchError}</div>`:''}${state.researchFeedback?`<div class="research-feedback">${state.researchFeedback}</div>`:''}</div></div>`+
    (state.researchDrawer?`<div class="research-drawer"><div class="drawer-head"><div><h2>选择当前研究设备</h2><span>切换保留每项已完成工作量</span></div>${control('research-close','关闭')}</div><div class="study-grid">${state.researchUnlocked.map(id=>{const item=studies[id];return `<button data-study="${id}" class="study-option ${state.researchId===id?'selected':''}"><img src="${asset}ai_tech_factory/${item.image}" alt=""><b>${item.name}</b><span>Lv.${item.level} · ${item.progress}</span><small>${item.effect}</small></button>`;}).join('')}</div></div>`:'');
}

const enhancementFixtureBranches=JSON.stringify({proficiency:['A','B','A'],repeat:['A','B',''],critical:['B','',''],adaptation:['A','B',''],memory:['B','A',''],deferred:['B','','']});
function enhancementSnapshot(){const e=state.enhance,signature=JSON.stringify(e.branches);if(e.weapon.join()==='proficiency,repeat,critical'&&e.defence.join()==='adaptation,memory,deferred'&&signature===enhancementFixtureBranches)return EnhancementModels.combatSnapshots[e.effective];const response=EnhancementModels.responseCases.find(r=>r.weapon.join()===e.weapon.join()&&r.defence.join()===e.defence.join()&&JSON.stringify(r.branches)===signature);return response?.snapshots[e.effective]||null;}

function enhancementBalance(){const e=state.enhance;return e.quoteUsed?e.balance:e.funds?'64.0 B':'2.1 K';}
function enhancementQuoteView(){const e=state.enhance,q=EnhancementModels.quotes[e.purchaseMode];return e.quoteUsed?'当前报价待刷新':!e.funds?'当前可成交0级 · 余额不足 · 首级需13.42 B碎片':`当前可成交${q.count}级 · 合计 ${q.price}碎片`;}
function enhancement(){
 const e=state.enhance,models=EnhancementModels,snapshot=enhancementSnapshot();
 const branchRoute=state.route.startsWith('enhancement/branch/'),effect=models.effects[e.effect],group=e.weapon.includes(e.effect)?e.weapon:e.defence,position=group.indexOf(e.effect),gates=models.positions[position];
 const current=e.branches[e.effect][e.node],gate=gates.nodeGates[e.node],unlocked=e.effective>=gate,disabledB=e.effect==='repeat'&&e.node===1;
 return moduleHead('全局强化','',`<span class="pill">碎片 ${enhancementBalance()}</span>`)+`<div class="enhancement-levels"><div class="enhance-level-strip"><img class="enhancement-emblem" src="${asset}ui/shell/enhancement.svg" alt=""><b>有效 E${e.effective}</b><span>购买 G${e.paid} + 世界 B${e.extra}</span>${control('enhance-level-source','等级来源','quiet')}</div><div class="enhancement-buy"><div>${control('enhance-one','购买1级',e.purchaseMode==='one'?'active':'')}${control('enhance-ten','最多购买10级',e.purchaseMode==='ten'?'active':'')}</div><span>${enhancementQuoteView()}</span>${control('enhance-buy',e.quoteUsed?'等待新报价':'确认购级','primary',!e.funds||e.quoteUsed)}</div></div>${e.receipt?`<div class="enhance-receipt"><b>上次成交</b><span>${e.receipt.count}级 · ${e.receipt.price}碎片 · 购买G${e.receipt.before}→${e.receipt.after}</span><small>当前新报价待取得，旧成交不重复使用</small></div>`:''}${e.feedback?`<div class="research-feedback">${e.feedback}</div>`:''}<div class="enhance-layout"><div class="enhance-groups">${[['weapon','武器作用顺序'],['defence','防御作用顺序']].map(([key,title])=>`<section class="enhance-chain"><h3>${title}</h3>${e[key].map((id,i)=>{const m=models.effects[id],p=models.positions[i];return `<article class="enhance-effect ${e.effect===id?'selected':''}" data-enhance-effect="${id}" data-order="${i+1}"><button class="enhance-select" data-action="enhance-view-${id}" aria-pressed="${e.effect===id}"><span class="effect-symbol">${m.symbol}</span><b>${m.name}</b><small>顺位${i+1} · ${e.effective>=p.effectGate?'已开放':'E'+p.effectGate+'开放'}</small><span class="enhance-path">${e.branches[id].map(x=>x||'—').join(' / ')}</span></button>${control('enhance-move-'+id,'前移','quiet')}</article>`;}).join('')}</section>`).join('')}</div><section class="enhance-detail" data-enhance-detail="${e.effect}"><div class="enhance-detail-heading"><span class="effect-symbol">${effect.symbol}</span><div><small>当前查看 · 顺位 ${position+1}</small><h2>${effect.name}</h2></div></div><p class="enhance-current">${snapshot?.[e.effect]?.summary||'当前完整效果待刷新，旧数值不再作为已生效效果'}</p><div class="enhance-active-branches">${snapshot?.[e.effect]?.branches||'顺位或分支已变化；等待完整效果快照'}</div><details class="enhance-node-details" ${state.enhanceOpen===undefined||state.enhanceOpen.includes(e.effect)?'open':''}><summary>分支节点与门槛</summary><div class="enhance-nodes">${gates.nodeGates.map((g,j)=>`<button data-enhance-node="${e.effect}:${j}" class="${e.effective>=g?'open':'locked'}"><small>节点${j+1} · E${g}</small><b>${e.branches[e.effect][j]||'未选'}</b><span>${e.effective<g?(e.branches[e.effect][j]?'保留选择 · 暂停生效':'未开放'):e.effect==='repeat'&&j===1&&e.branches[e.effect][j]==='B'?'B保留 · 功能不启用':e.branches[e.effect][j]?'当前已生效':'可选择'}</span></button>`).join('')}</div></details></section></div>${branchRoute?`<dialog class="branch-sheet" aria-label="强化分支选择"><div class="drawer-head"><div><span class="eyebrow">${effect.name} / NODE ${e.node+1}</span><h2>节点${e.node+1} · 有效等级${gate}</h2><span>当前路径 ${e.branches[e.effect].map(x=>x||'—').join(' → ')} · 当前E${e.effective}</span></div>${control('back','返回强化')}</div>${!unlocked?'<div class="note warn">门槛未满足；原选择保留并暂不生效。</div>':''}<div class="branch-options">${['A','B'].map(c=>`<button data-enhance-choice="${c}" class="${e.choice===c?'selected':''}" ${!unlocked||c==='B'&&disabledB?'disabled':''}><b>路径 ${c} ${current===c?'· 当前选择':''}</b><p>${c==='A'?effect.a:effect.b[e.node]}</p>${c==='B'&&disabledB?'<small>现行规则禁用；已存选择不删除。</small>':''}</button>`).join('')}</div><div class="branch-confirm"><span>${e.choice?'候选 '+e.choice+' · 当前选择仍为 '+(current||'未选'):'选择后比较，再确认应用'}</span>${control('enhance-branch-apply','确认分支','primary',!unlocked||!e.choice||e.choice===current)}</div></dialog>`:''}`;
}
function crew() {
  const member=state.crewMembers[state.crewId], error=crewAdmission(), planetJob=state.crewDraft.startsWith('planet-');
  const available=Object.entries(state.crewMembers).filter(([id,m])=>m.available);
  const target=state.planets.find(p=>p.id===state.crewPlanet);
  return moduleHead('船员名册 · '+available.length+'人可用','',`<span class="pill">${member.name} · Lv.${member.level}</span>`)+
    `<div class="crew-room"><div class="crew-roster">${available.map(([id,m])=>`<button data-crew="${id}" class="crew-person ${state.crewId===id?'selected':''}"><span class="job-badge">${m.job==='idle'?'◇':m.job==='planet-build'?'⚒':m.job==='planet-explore'?'◎':'◈'}</span><span><b>${m.name}</b><small>Lv.${m.level} · ${memberJob(m)}</small></span><div class="meter"><i style="width:${m.experienceRatio*100}%"></i></div></button>`).join('')}<div class="crew-next">下位船员：${Object.values(state.crewMembers).find(m=>!m.available)?.name} · 通关45关开放</div></div><div class="person-console"><div class="person-heading"><span class="job-badge large">${member.job==='idle'?'◇':'◈'}</span><div><span class="eyebrow">CREW / CURRENT ASSIGNMENT</span><h2>${member.name}</h2><span>Lv.${member.level} · 经验 ${member.experience} / ${member.experienceRequired}</span></div></div><div class="meter"><i style="width:${member.experienceRatio*100}%"></i></div><div class="current-job"><small>当前实际占用</small><b>${memberJob(member)}</b><span>${({research:'科研速度 ×1.6；完成后自动续研最短项目',equipment:'装备属性 ×1.331；每秒尝试全部启用槽位正常付费购级',reactor:'反应炉总能源 ×1.9；每秒尝试购级并均分',enhancement:'直接碎片 ×1.3；每秒尝试购1级全局强化',idle:'当前无岗位占用'})[member.job]||''}</span></div><div class="dispatch-draft"><h3>派遣候选</h3><label>岗位<select id="crew-target">${Object.entries(jobs).filter(([id])=>id!=='hyperspace').map(([id,name])=>`<option value="${id}" ${id===state.crewDraft?'selected':''}>${name}</option>`).join('')}</select></label>${planetJob?`<label>星球<select id="crew-planet">${state.planets.filter(p=>p.available).map(p=>`<option value="${p.id}" ${p.id===target.id?'selected':''}>${p.name}</option>`).join('')}</select></label>${state.crewDraft==='planet-build'?`<label>施工设施<select id="crew-facility">${Object.values(target.facilities).map(f=>`<option value="${f.id}" ${f.id===state.crewFacility?'selected':''}>${f.name} · 额外人员${f.extraCrew}</option>`).join('')}</select></label>`:''}`:''}${state.crewDraft==='equipment'?`<label>自动购级模式<select id="crew-mode">${['1','10','MAX'].map(v=>`<option ${v===state.crewMode?'selected':''}>${v}</option>`).join('')}</select></label>`:''}${error?`<div class="note warn">${error}</div>`:''}${state.crewError?`<div class="note bad">${state.crewError}</div>`:''}<div class="secondary-actions">${control('crew-apply','确认派遣','primary',!!error)}${control('crew-release','释放当前占用','',member.job==='idle'||member.job==='hyperspace')}${control('crew-target','查看候选目标')}${control('back','返回来处','quiet')}</div><details class="technical-details"><summary>岗位与任务规则</summary><p>派遣候选在确认前不会释放当前占用。任务按实际探索或工程完成提供经验；系统岗位加成由当前工作决定。施工完成后，施工人员返回空闲。</p></details></div></div></div>`;
}
function routeName(id=state.routeId) {return HyperspaceTasks.names(id);}
function taskStatus(task){return {idle:'待命',running:'进行中',ready:'待领取',claimed:'已领取',failed:'未完成'}[task.status];}
const hyperTabs=[['routes','路线任务'],['warehouse','仓库'],['formation','无人机编队'],['forge','改造'],['filter','过滤'],['materials','材料']];
function hyperNav() {return `<div class="subnav">${hyperTabs.map(([id,name])=>`<button data-route="hyperspace/${id}" class="${state.route==='hyperspace/'+id?'active':''}">${name}</button>`).join('')}</div>`;}
function droneStrip() {
  return `<div class="drone-strip"><span>当前对象</span>${Object.entries(drones).filter(([id])=>!state.workshop||state.workshop.store[id]).map(([id,d])=>`<button data-drone="${id}" class="${state.droneId===id?'active':''}">${d.name}</button>`).join('')}</div>`;
}
function droneNameList(ids) {return ids.length?ids.map(id=>drones[id].name).join(' / '):'无';}

function hyperspace() {
  HyperWorkshop.ensure(state,drones);
  const part=state.route.split('/')[1]||'routes', d=drones[state.droneId];
  let body='';

  if(part==='warehouse') body=`<div class="warehouse-heading"><span>主仓 3 / 40</span><span>溢出0 · 封存0</span><span>已选 ${state.droneSelection.length}</span></div><div class="drone-grid">${Object.entries(drones).map(([id,item])=>`<article class="drone-card ${state.droneId===id?'selected':''}"><img src="${asset}hyperspace/icons/${item.icon}" alt=""><h3>${item.name}</h3><p>${item.quality} · Lv.${item.level}<br>${item.affix}</p><span class="pill">${state.equippedDrones.includes(id)?'已装备':'主仓'}</span><div>${control('drone-pick-'+id,state.droneSelection.includes(id)?'取消选中':'选中')}${control('drone-detail-'+id,'详情')}</div></article>`).join('')}</div><div class="secondary-actions">${control('warehouse-formation','以所选无人机编队','primary',!state.droneSelection.length)}${control('warehouse-forge','改造所选对象','',state.droneSelection.length!==1)}${control('warehouse-filter','过滤规则')}${control('warehouse-sealed','封存 / 整理')}</div>`;
  if(part==='drone'){const location=state.workshop.store[state.droneId],available=!!location,main=location==='main',sealed=location==='sealed';body=`${droneStrip()}<div class="drone-detail">${HyperWorkshop.art(d,asset)}<div><h2>${d.name}</h2><p>${d.quality} · 层级${d.level} · ${d.weapon}</p><p>当前词缀 ${d.affix}</p><span class="pill ${main?'good':'warn'}">${!available?'已不在仓库':sealed?'封存 · 达到第'+state.workshop.claimAt[state.droneId]+'关后领取解封':location==='overflow'?'溢出 · 整理至主仓后才可装备':state.equippedDrones.includes(state.droneId)?'主仓 · 当前已装备':'主仓 · 可选择装备'}</span></div></div><div class="secondary-actions">${control('drone-to-formation','进入编队','primary',!main)}${control('drone-to-forge','进入改造','',!available||sealed)}${control('drone-hanging','挂设成长','',!available||sealed)}${control('drone-favorite','收藏保护','',!available)}${control('back','返回仓库','quiet')}</div>`;}

  if(part==='formation') body=`${droneStrip()}<div class="formation-stage"><div class="formation-mother"><img src="${asset}ui/ships/fleet_20261019/03-cruiser.png" alt="母舰预览"><span>巡洋舰 · 容量3</span></div><div class="formation-slots">${[0,1,2].map(i=>`<div class="formation-slot"><small>无人机位 ${i+1}</small><b>${state.formationDraft[i]?drones[state.formationDraft[i]].name:'空位'}</b></div>`).join('')}</div></div><div class="formation-compare"><div><small>当前编队</small><b>${droneNameList(state.equippedDrones)}</b></div><div><small>本次候选</small><b>${droneNameList(state.formationDraft)}</b></div></div>${state.formationError?`<div class="note warn">${escapeText(state.formationError)}</div>`:''}${state.formationPreview?`<div class="transaction-preview"><b>应用前装卸确认</b><p>将装备：${droneNameList(state.formationPreview.equip)}<br>将卸下：${droneNameList(state.formationPreview.remove)}</p>${control('formation-confirm','确认应用','primary')}${control('formation-cancel','取消')}</div>`:''}<div class="secondary-actions">${control('formation-set','将当前对象放入候选')}${control('formation-preview','查看本次装卸','primary')}${control('back','返回来处','quiet')}</div>`;




  const workshop=HyperWorkshop.render(part,state,drones,control,asset);if(workshop!==null)body=workshop;const filter=FilterWorkbench.render(part,state,control);if(filter!==null)body=filter;const forge=ForgeWorkbench.render(part,state,drones,control,asset);if(forge!==null)body=forge;const task=HyperspaceTasks.render(part,state,drones,control,asset);if(task!==null)body=task;
  return moduleHead('超空间 · '+(hyperTabs.find(row=>row[0]===part)?.[1]||{drone:'无人机详情',sealed:'仓储处理',hanging:'挂设成长',protection:'收藏保护',receipt:'本次回执',manual:'手动挑战','filter-import':'审阅规则导入','filter-export':'导出规则',presets:'编队预设',legends:'传说图鉴'}[part]),['routes','manual','receipt'].includes(part)?'':`浏览 ${routeName()} · 当前无人机 ${d.name}`)+hyperNav()+body;
}
function settings() {
  if(state.route.includes('/danger/')) return danger();
  const m=state.maintenance,save=MaintenanceModels.saveStates[m.save];
  const tabs=`<div class="subnav">${[['save','保存与恢复'],['preferences','音画与自动保存'],['danger/reforge','重铸'],['danger/import','导入'],['danger/new','新游戏']].map(([id,name])=>`<button data-route="settings/${id}" class="${state.route==='settings/'+id?'active':''}">${name}</button>`).join('')}</div>`;
  if(state.route==='settings/preferences')return moduleHead('音画与自动保存','当前个人设置与可修改值')+tabs+`<div class="preferences-grid"><section><h2>声音与表现</h2><label><input id="pref-music" type="checkbox" ${m.music?'checked':''}>音乐 ${m.music?'开启':'关闭'}</label><label><input id="pref-effects" type="checkbox" ${m.effects?'checked':''}>音效 ${m.effects?'开启':'关闭'}</label><label>伤害数字<select id="pref-damage">${[['all','全部'],['critical','仅暴击'],['off','关闭']].map(([v,t])=>`<option value="${v}" ${m.damage===v?'selected':''}>${t}</option>`).join('')}</select></label></section><section><h2>保存与引导</h2><label>自动保存间隔<input id="pref-interval" type="number" min="0" max="86400" value="${m.interval}">现实秒</label><small>0为关闭；暂停不阻止保存，不推进游戏时间。</small><label><input id="pref-skip" type="checkbox" ${m.skip?'checked':''}>自动跳过引导提示</label>${control('archive-tutorial','主动回看飞行手册','quiet')}</section></div>${m.feedback?`<div class="note">${m.feedback}</div>`:''}`;
  return moduleHead('保存与恢复','查看保存状态、重试或载入备份')+tabs+`<div class="save-dashboard ${m.save}"><div class="save-current"><div class="save-state-mark" aria-hidden="true">${m.save==='saved'?'✓':['failed','recovery'].includes(m.save)?'!':'◷'}</div><div><small>当前进度 · 保存状态</small><h2>${save.title}</h2><p>${save.description}</p></div></div><ol class="save-timeline">${[['queued','排队'],['writing','写入'],['saved','已确认']].map(([id,title],i)=>`<li class="${['queued','writing','saved'].indexOf(m.save)>=i?'reached':''}" ${m.save===id?'aria-current="step"':''}><i aria-hidden="true"></i><span>${title}</span></li>`).join('')}</ol><div class="save-primary-actions">${control('save-retry',['failed','recovery'].includes(m.save)?'重试保存当前进度':'保存当前进度','primary',['queued','writing'].includes(m.save))}${control('save-backup','有效备份 / 恢复')}${control('danger-import','导入存档')}</div><div class="save-location"><small>当前目录</small><b>${escapeText(m.directory)}</b></div><details class="save-directory-editor"><summary>更换保存目录</summary><label>候选目录 <input id="save-directory" value="${escapeText(m.directoryDraft)}"></label><div class="secondary-actions">${control('save-directory-apply','使用候选目录')}${control('save-picker','选择目录')}</div></details><details class="technical-details"><summary>技术详情</summary><p>${save.technical||'等待保存结果'}</p></details>${m.feedback?`<div class="note">${escapeText(m.feedback)}</div>`:''}</div><div class="maintenance-summary"><article><h3>个人设置</h3><p>音乐${m.music?'开启':'关闭'} · 音效${m.effects?'开启':'关闭'} · 自动保存${m.interval}现实秒</p>${control('settings-audio','声音与显示')}</article><article><h3>危险事务</h3><p>重铸与新游戏会改变航程进度。</p>${control('danger-reforge','重铸')}${control('danger-new','新游戏')}</article></div>`;
}
function dangerMatches(record,kind,source){return record&&record.kind===kind&&record.source===source&&(kind!=='reforge'||record.planetId===state.planetId&&record.retained.join()===state.maintenance.retained.join())&&(kind!=='new'||record.clearSettings===state.maintenance.clearSettings);}
function danger() {
 const kind=state.route.split('/')[2]||'reforge',m=state.maintenance;state.dangerKind=kind;
 const title={reforge:'重铸',import:'导入存档',new:'新游戏'}[kind];
 const source=kind==='reforge'?selectedPlanet().name:kind==='import'?m.importSource:m.newDirectory;state.dangerSource=source;
 const allowed=kind!=='reforge'||Object.values(selectedPlanet().facilities).some(f=>f.type==='shipyard'&&f.state==='owned');
 const preview=dangerMatches(state.dangerPreview,kind,source)?state.dangerPreview:null;
 const matrix=MaintenanceModels.reforge,result=dangerMatches(state.dangerResult,kind,source)?state.dangerResult:null;
 return moduleHead(title,kind==='reforge'?'确认保留与损失后开始新一轮':kind==='import'?'先查看存档内容，再决定是否载入':'选择新档位置，确认后开始新航程')+`<div class="danger-route"><div class="transaction-source"><h2>本次${title}对象</h2>${kind==='reforge'?`<label>星球<select id="danger-planet">${state.planets.filter(p=>p.available).map(p=>`<option value="${p.id}" ${p.id===state.planetId?'selected':''}>${p.name}</option>`).join('')}</select></label><p>选择要保留的无人机</p><div class="retained-drones">${Object.entries(drones).map(([id,d])=>`<label><input type="checkbox" data-retain-drone="${id}" ${m.retained.includes(id)?'checked':''}>${d.name}</label>`).join('')}</div>${allowed?'':'<div class="note warn">所选星球船坞尚未领取，当前不能重铸；可先查看重置范围。</div>'}`:kind==='import'?`<label>来源文件<input id="import-source" value="${escapeText(m.importSource)}"></label><p>确认载入后将切换到此存档。不兼容文件不会被修改。</p>`:`<label>新档目录<input id="new-directory" value="${escapeText(m.newDirectory)}"></label><label><input id="new-clear-settings" type="checkbox" ${m.clearSettings?'checked':''}>同时重置个人设置</label><p>建立独立新航程，原有效档或损坏文件不会因查看而覆盖。</p>`}${m.dangerError?`<div class="note bad">${escapeText(m.dangerError)}</div>`:''}${control('danger-preview','查看影响与损失','primary',!allowed)}</div>${preview?`<div class="transaction-preview"><span class="eyebrow">确认前请查看</span><h2>${title} · ${escapeText(preview.source)}</h2><div class="loss-grid"><div><b>清除 / 替换</b><ul>${(kind==='reforge'?[...matrix.clear,'将失去未保留无人机：'+droneNameList(preview.lost)]:kind==='import'?['当前进度将替换为此存档的进度','当前战斗将重新开始；进行中的手动挑战将中断']:['当前航程切换至新档初始进度',preview.clearSettings?'个人设置重置':'个人设置保留']).map(t=>`<li>${t}</li>`).join('')}</ul></div><div><b>保留 / 收益</b><ul>${(kind==='reforge'?[...matrix.keep,...(selectedPlanet().id==='1'?matrix.gain:['本星球标记征服：装备有效等级+15、免费充能+10%、强化有效等级+1、幸运+100','保留无人机封存至所属星球门槛；仓库/保留容量各+10','新起点第'+({'2':10,'3':15,'4':20,'5':25,'6':30})[selectedPlanet().id]+'关；建立全新战场']), '将保留并封存：'+droneNameList(preview.retained)]:kind==='import'?['将载入：第40关 · '+preview.source,'在线剩余任务与待领回执按来源恢复','载入完成后会另行报告是否保存成功']:['目标目录：'+preview.source,'原存档保留；新航程另行保存']).map(t=>`<li>${escapeText(t)}</li>`).join('')}</ul></div></div><details class="technical-details"><summary>技术详情</summary><p>事务 ${preview.kind} · ${preview.id} · 来源 ${escapeText(preview.source)}</p></details>${control('danger-confirm','确认'+(kind==='import'?'载入存档':title),'primary')}${control('danger-cancel','取消预览')}</div>`:result?'':'<div class="empty-preview">查看本次影响后再确认；修改选择需要重新查看。</div>'}${result?`<div class="receipt danger-result"><b>${escapeText(result.message)}</b><p>${result.next}</p><details class="technical-details"><summary>技术详情</summary><p>${escapeText(result.technical)}</p></details>${control('save-open','查看保存与重试','primary')}</div>`:''}<div class="secondary-actions">${control('back','返回原工作点','quiet')}</div></div>`;
}
function archive(){
 const a=state.archive,tab=state.route.split('/')[1]||a.tab;a.tab=tab;
 const tabs=[['tutorial','飞行手册'],['intel','当前敌情'],['notifications','通知档案'],['statistics','伤害明细']];
 let body='';
 if(tab==='tutorial'){const help=MaintenanceModels.tutorials[a.tutorial];body=`<div class="archive-split"><div class="archive-index">${Object.entries(MaintenanceModels.tutorials).map(([id,t])=>`<button data-tutorial="${id}" class="${id===a.tutorial?'active':''}"><b>${t[0]}</b><span>${a.completed.includes(id)?'已实践':'可回看'}</span></button>`).join('')}</div><article class="archive-paper"><span class="eyebrow">FLIGHT MANUAL / ${a.tutorial.toUpperCase()}</span><h2>${help[0]}</h2><div class="manual-diagram">${({equip:['选中槽位','比较候选','确认换装'],upgrade:['选择数量','查看总费用','购级结果'],pickup:['资源出现','点击或等待','实际入账'],retreat:['防御耗尽','撤退航行','恢复后出击'],clear:['终波清空','结算奖励','查看解锁']})[a.tutorial].map((x,i)=>(i?'<i>→</i>':'')+'<span>'+x+'</span>').join('')}</div><p>${help[1]}</p><div class="secondary-actions">${control('tutorial-target','前往对应工作点','primary')}${a.guidePaused?control('tutorial-continue','继续航行'):''}</div><small>${a.guidePaused?'当前为首次引导暂停；继续仅释放引导暂停。':'主动回看不暂停航程，也不会重置已完成记录。'}</small></article></div>`;}
 if(tab==='intel'){const n=a.intel.find(x=>x.id===a.enemy);body=`<div class="archive-split"><div class="archive-index">${a.intel.map(n=>`<button data-intel="${n.id}" class="${a.enemy===n.id?'active':''}">${n.name}<span>${n.tier}</span></button>`).join('')}</div><article class="intel-paper"><img src="${asset}${n.texture}" alt="${n.name}敌舰外观" data-visual-key="${n.visual_key}"><div><span class="eyebrow">CURRENT ENEMY</span><h2>${n.name}</h2><span class="pill">${n.tier}</span><dl><dt>装甲</dt><dd>${n.armour}</dd><dt>护盾</dt><dd>${n.shield}</dd></dl><p>${n.mechanics}</p></div></article></div>`;}
 if(tab==='notifications')body=`<div class="notification-header"><h2>未读 ${a.notifications.filter(n=>!n.read).length}</h2></div><div class="notification-list">${a.notifications.map(n=>`<article><div><small>${n.key.split(':')[0]==='unlock'?'开放':'科研'}</small><h3>${n.title}</h3><span>${n.seen?'已见':'未见'} · ${n.read?'已读':'未读'}</span></div><div><button data-notification-seen="${n.key}" ${n.seen?'disabled':''}>${n.seen?'已见':'标记已见'}</button><button data-notification-read="${n.key}" ${n.read?'disabled':''}>${n.read?'已读':'阅读此条'}</button></div></article>`).join('')}</div>`;
 if(tab==='statistics')body=`<div class="statistics-paper"><table><thead><tr><th>来源</th><th>总伤害</th><th>护盾</th><th>装甲</th></tr></thead><tbody><tr><td>武器1 · 脉冲</td><td>128.0 K</td><td>44.0 K</td><td>84.0 K</td></tr><tr><td>武器2 · 导弹</td><td>94.0 K</td><td>32.0 K</td><td>62.0 K</td></tr></tbody></table></div>`;
 return moduleHead(tabs.find(x=>x[0]===tab)?.[1]||'航行档案','')+`<div class="subnav">${tabs.map(([id,name])=>`<button data-route="archive/${id}" class="${tab===id?'active':''}">${name}</button>`).join('')}</div>`+body;
}
function catalog() {
  return moduleHead('全系统工作对象','返回所选对象的上次工作位置')+`<div class="system-objects">${modules.map(([id,name,en])=>`<button class="object-card" data-module="${id}" style="text-align:left;white-space:normal;min-height:80px"><span class="eyebrow">${en}</span><h3>${name}</h3></button>`).join('')}</div>`;
}
function dock() {
  if(state.collapsed) return '';
  if(state.module==='equipment'&&state.route!=='equipment')return '';
  if(state.module==='equipment') {
    const q=equipmentQuote(), disabled=!q.known||(q.action==='equip-buy'&&!q.canPay)||(q.action==='equip-apply'&&!q.canSwitch);
    return `<div class="dock-summary"><b>${EquipmentWorkbench.slot(state.slot).label} · ${state.fits[state.slot]} Lv.${state.levels[state.slot]}</b><span>${q.label} · ${q.known?'':'上次读数 '}${q.current} → <strong>${q.next}</strong> · ${comparisonCycle()}</span><span>本次费用 <strong>${q.price}</strong></span></div><div class="dock-buttons">${control(q.action,currentCooldown()>0&&q.action==='equip-apply'?'冷却剩余'+currentCooldown()+'游戏秒':q.label,'primary',disabled)}${control('equip-compare',state.candidate?'查看购级':'更换候选')}</div>`;
  }
  if(state.module==='reactor') {
    const before=effectSnapshots[state.actual.join()],after=effectSnapshots[state.alloc.join()];
    return `<div class="dock-summary"><b>整组供能草稿 · ${sum(state.alloc)}/100 · 剩余${100-sum(state.alloc)}</b><span>手动 ${state.actual.join('/')} → ${state.alloc.join('/')} · 免费供能保持</span><span>攻击 ${before?.attack||'待读数'} → ${after?.attack||'待效果预览'} / 熔炼 ${before?.income||'待读数'} → ${after?.income||'待效果预览'} · 费用0</span>${state.reactorError?`<strong class="reactor-fixed-error">${state.reactorError}</strong><span>当前 ${state.actual.join('/')}；本组目标 ${state.alloc.join('/')} 尚未接纳。</span>`:''}</div><div class="dock-buttons">${control('reactor-apply',state.reactorError?'重新确认整组':'确认整组调配','primary',!changed()||sum(state.alloc)>100)}${control('reactor-reset','还原')}</div>`;
  }

  if(state.module==='planet') {const p=selectedPlanet(),f=selectedFacility();return `<div class="dock-summary"><b>${p.name} · ${f.name}</b><span>${facilityStatus(p,f)} · ${f.work}/${f.required}次</span><span>${f.state==='ready'?'领取后本设施收益生效':f.effectSummary}</span></div><div class="dock-buttons">${f.state==='ready'?control('planet-claim','领取此设施收益','primary'):control('planet-crew',f.extraCrew?'调整额外施工人员':'查看探索人员','primary',f.state==='locked'||f.state==='owned')}</div>`;}
  if(state.module==='galaxy'){const n=state.galaxyNodes[state.galaxyNode];return `<div class="dock-summary"><b>第一星系 · ${n.state==='fog'?'未探索节点':n.name}</b><span>${galaxyWorkStatus(n)} · ${n.progress}%</span><span>工程人员 ${crewCount('galaxy')}/6 · 完成自动生效</span></div><div class="dock-buttons">${control('galaxy-crew','调整星系人员','primary')}</div>`;}
  return '';
}
function render() {
  if(renderedRoute===state.route && !renderedCollapsed && !state.collapsed) rememberScroll();
  document.body.classList.toggle('work-family',state.family==='work');
  document.body.classList.toggle('collapsed',state.collapsed);
  document.querySelectorAll('[data-family]').forEach(button=>button.classList.toggle('active',button.dataset.family===state.family));
  $('#workspace').dataset.view=state.module;
  $('#nav').innerHTML=nav(); $('#collapse').textContent=state.collapsed?'展开工作区':'收起工作区'; $('#pause').textContent=state.paused?'▶ 继续':'Ⅱ 暂停';
  const previousBranch=$('.branch-sheet');
  const previousBudget=$('.investment-console.is-open');
  const budgetFocus=document.activeElement?.closest('.investment-console')?{id:document.activeElement.id,action:document.activeElement.dataset.action}:null;
  const budgetScroll=previousBudget?.scrollTop||0,preciseOpen=$('.precise-investment')?.open||false;
  if($('.enhance-detail')){const id=$('.enhance-detail').dataset.enhanceDetail,opened=new Set(state.enhanceOpen||[]);if($('.enhance-node-details')?.open)opened.add(id);else opened.delete(id);state.enhanceOpen=[...opened];}
  let body=state.module==='catalog'?catalog():({reactor,equipment,planet,galaxy,research,crew,enhancement,hyperspace,settings,archive}[state.module]||catalog)();
  if(state.collapsed) body=`<div class="resting"><div class="rest-icon">◈</div><h1>远航仍在继续</h1><p>当前对象与草稿保持。</p>${control('expand','继续当前工作','primary')}</div>`;
  else if(state.family==='work'&&state.module!=='catalog') body=workWrapper(body);
  const branchFocus=document.activeElement?.closest('.branch-sheet')?.querySelector(':focus')?.dataset.enhanceChoice;
  const branchScroll=$('.branch-sheet')?.scrollTop||0;
  $('#work-content').innerHTML=body;
  const budget=$('.investment-console.is-open');
  if(budget){
    budget.scrollTop=budgetScroll;if(preciseOpen&&$('.precise-investment'))$('.precise-investment').open=true;
    const focus=budgetFocus?.id?document.getElementById(budgetFocus.id):budgetFocus?.action?budget.querySelector('[data-action="'+budgetFocus.action+'"]'):!previousBudget?budget.querySelector('[data-action="research-budget-close"]'):null;
    focus?.focus({preventScroll:true});
  }else if(previousBudget&&state.module==='research')$('[data-action="research-budget-open"]')?.focus({preventScroll:true});
  const branch=$('.branch-sheet');
  if(branch){
    branch.addEventListener('cancel',event=>{event.preventDefault();back();});
    branch.addEventListener('keydown',event=>{
      if(event.key!=='Tab')return;
      const controls=[...branch.querySelectorAll('button:not(:disabled),[tabindex="0"]')];
      if(!controls.length)return;
      event.preventDefault();
      const index=controls.indexOf(document.activeElement);
      controls[(index+(event.shiftKey?-1:1)+controls.length)%controls.length].focus();
    });
    branch.showModal();branch.scrollTop=branchScroll;
    if(branchFocus)branch.querySelector('[data-enhance-choice="'+branchFocus+'"]')?.focus({preventScroll:true});
  }else if(previousBranch&&state.module==='enhancement'){
    $('[data-enhance-node="'+state.enhance.effect+':'+state.enhance.node+'"]')?.focus({preventScroll:true});
  }
  $('#action-dock')?.remove();
  const actions=dock();
  if(actions) {const element=document.createElement('div');element.id='action-dock';element.innerHTML=actions;$('#workspace').append(element);}
  $('#notice').textContent=state.notice;
  $('#save-alert')?.remove();if(['failed','recovery'].includes(state.maintenance.save)){const alert=document.createElement('button');alert.id='save-alert';alert.dataset.action='save-open';alert.textContent=MaintenanceModels.saveStates[state.maintenance.save].title+' · 查看与恢复';$('#battle').append(alert);}
  $('#fragments').textContent=enhancementBalance();
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
  if(window.BattleDesign)window.BattleDesign.fit();
  else if($('#world'))$('#world').style.transform=`scale(${s})`;
  const battleMetrics=window.BattleDesign?.stats();
  $('#geometry').textContent=battleMetrics?`${innerWidth} × ${innerHeight} · 安全框${battleMetrics.visualBounds[2]-battleMetrics.visualBounds[0]} × ${battleMetrics.visualBounds[3]-battleMetrics.visualBounds[1]}u · s ${battleMetrics.scale.toFixed(4)}`:`${innerWidth} × ${innerHeight} · 战场 ${Math.round(572*s)} × ${Math.round(960*s)} · s ${s.toFixed(3)}`;
  renderPipes();
}
function openDetail(title,text) {
  $('#inspect-detail')?.remove();
  const dialog=document.createElement('dialog'); dialog.id='inspect-detail';
  dialog.innerHTML=`<h2>${title}</h2><p>${text}</p><button data-action="close-detail">返回原工作点</button>`;
  document.body.append(dialog);dialog.showModal();
}
function invalidateForge() {state.forgePreview=null;state.forgeResult=null;if(state.forgeDesk){state.forgeDesk.preview=null;state.forgeDesk.feedback='';}}
function selectCrew(id){state.crewId=id;const m=state.crewMembers[id];state.crewDraft=m.job==='hyperspace'?'idle':m.job;state.crewPlanet=m.targetPlanet;state.crewFacility=m.targetFacility;state.crewMode=m.mode;state.crewError='';}
function syncDemoCrewTargets() {
  for(const p of state.planets){if(!crewCount('planet-explore',p.id)){p.running=false;p.automatic=false;p.elapsed='0';p.duration='0';}}
  const p=selectedPlanet(),f=selectedFacility();state.planet=f.state==='building'?(facilityStatus(p,f)==='施工中'?'building':'paused'):f.state;
}
function validAmountDraft(text) {return /^\d+$/.test(text.trim());}
function action(a) {
  if(state.module==='equipment'&&EquipmentWorkbench.handle(a,state,{go:goRoute,notify})){render();return;}
  if(state.module==='hyperspace'&&HyperspaceTasks.handle(a,state,drones,control,notify,goRoute)){render();return;}
  if(state.module==='hyperspace'&&ForgeWorkbench.handle(a,state,drones,control,notify,goRoute)){render();return;}
  if(state.module==='hyperspace'&&FilterWorkbench.handle(a,state,control,notify,goRoute)){render();return;}
  if(state.module==='hyperspace'&&HyperWorkshop.handle(a,state,drones,control,notify,goRoute)){render();return;}
  if(a.startsWith('reactor-amount-')&&a!=='reactor-amount-apply'){state.reactorEditIndex=Number(a.split('-')[2]);openDetail('设置设备分配目标',`当前手动值 ${state.actual[state.reactorEditIndex]}。<label>目标金额 <input id="reactor-amount-input" value="${state.alloc[state.reactorEditIndex]}"></label><button data-action="reactor-amount-apply" class="primary">保留为分配草稿</button>`);return;}
  else if(a==='reactor-amount-apply'){const value=$('#reactor-amount-input').value;if(validAmountDraft(value)&&Number(value)<=100){state.alloc[state.reactorEditIndex]=Number(value);$('#inspect-detail').close();state.reactorReceipt='';state.reactorIntent='custom';notify('设备目标已保留为草稿，尚未应用');}else{notify('当前演示容量100以内输入整数；实际分配不变');return;}}
  else if(a==='reactor-task') {state.alloc=[60,35,5,0];state.reactorError='';state.reactorReceipt='';state.reactorIntent='custom';notify('调配方案已展开：武器增加15，防御保持，熔炼减少15');}
  else if(a==='reactor-apply') {
    state.reactorError='';state.reactorReceipt='';
    if(sum(state.alloc)>100)state.reactorError='超过手动预算，未应用，原供能保持。';
    else if(state.reactorIntent==='equal'){state.reactorLastPlan={kind:'equal',command:'distribute'};state.actual=[...state.alloc];state.reactorReceipt='均分命令已接纳：'+state.actual.join('/')+'；免费供能保持，效果读数已更新。';notify(state.reactorReceipt);}
    else if(state.reactorFailAt>=0)state.reactorError='本组金额未接纳：'+['武器','防御','熔炼','凝聚'][state.reactorFailAt]+'目标校验拒绝；整组实际供能保持，草稿保留。';
    else {const ids=['weapons','defence','smelting','condensation'].slice(0,state.reactor==='opened'?4:3);state.reactorLastPlan={kind:'amounts',amount_texts:Object.fromEntries(ids.map((id,i)=>[id,String(state.alloc[i])]))};state.actual=[...state.alloc];state.reactorReceipt='整组金额已接纳：'+state.actual.join('/')+'；免费供能保持。'+(effectSnapshots[state.actual.join()]?'效果读数已更新。':'实际效果读数待取得。');notify(state.reactorReceipt);}
  }
  else if(a==='reactor-reset') {state.alloc=[...state.actual];state.reactorError='';state.reactorReceipt='';}
  else if(a==='reactor-equal') {state.alloc=state.reactor==='opened'?[25,25,25,25]:[34,33,33,0];state.reactorError='';state.reactorReceipt='';state.reactorIntent='equal';notify('均分草稿已准备，确认后调用均分命令；免费供能保持');}
  else if(a==='reactor-clear') {state.alloc=[0,0,0,0];state.reactorError='';state.reactorReceipt='';state.reactorIntent='clear';notify('清零草稿已准备，免费供能保留');}
  else if(a==='equip-compare') {state.candidate=!state.candidate;state.equipmentMode='one';if(state.equipment==='compare')state.equipment='normal';}
  else if(a==='equip-mode') {state.candidate=false;state.equipmentMode=state.equipmentMode==='max'?'one':'max';}


  else if(a==='planet-claim') {const f=selectedFacility();if(f.state==='ready'){f.state='owned';state.planet='owned';notify(selectedPlanet().name+' / '+f.name+'已领取，收益生效');}}
  else if(a==='planet-crew'||a==='planet-explorer') {const p=selectedPlanet(),f=selectedFacility(),job=a==='planet-explorer'||!f.extraCrew?'planet-explore':'planet-build';const actual=Object.entries(state.crewMembers).find(([id,m])=>m.available&&m.job===job&&m.targetPlanet===p.id&&(job!=='planet-build'||m.targetFacility===f.id));if(actual){selectCrew(actual[0]);}else{const idle=Object.entries(state.crewMembers).find(([id,m])=>m.available&&m.job==='idle');if(idle)selectCrew(idle[0]);state.crewDraft=job;state.crewPlanet=p.id;state.crewFacility=f.id;notify('当前目标暂无人员；已定位空闲成员候选，尚未派遣');}goRoute('crew');return;}
  else if(a==='planet-auto') {const p=selectedPlanet();p.automatic=!p.automatic;notify(p.automatic?'自动探索已开启':'本次探索仍继续，完成后停止');}
  else if(a==='planet-cancel') {openDetail('立即取消 '+selectedPlanet().name+'探索','本次探索进度清零、自动探索关闭并释放探索人员；已完成施工次数及待领设施保留。'+control('planet-cancel-confirm','确认立即取消','danger'));return;}
  else if(a==='planet-cancel-confirm'){const p=selectedPlanet();for(const m of Object.values(state.crewMembers))if(m.job==='planet-explore'&&m.targetPlanet===p.id)m.job='idle';p.running=false;p.elapsed='0';p.duration='0';p.automatic=false;syncDemoCrewTargets();$('#inspect-detail').close();notify('本次探索已取消并释放探索人员；施工次数保留');}
  else if(a==='planet-buff') {state.dangerSource=selectedPlanet().name;goRoute('settings/danger/reforge');return;}
  else if(a==='enhance-level-source'){const e=state.enhance;openDetail('强化等级来源',`购买等级G${e.paid}，费用只按购买等级报价；世界永久额外等级B${e.extra}；当前有效等级E${e.effective}用于效果与门槛。`);return;}
  else if(a==='enhance-one'||a==='enhance-ten'){state.enhance.purchaseMode=a.endsWith('one')?'one':'ten';}
  else if(a==='enhance-buy'){const e=state.enhance;if(e.funds&&!e.quoteUsed){const q=EnhancementModels.quotes[e.purchaseMode];e.receipt={count:q.count,price:q.price,before:e.paid,after:q.paid};e.paid=q.paid;e.effective=q.effective;e.quoteUsed=true;e.balance=q.balance;e.feedback='成交已记录；顺位与分支保持，等待新报价。';}}
  else if(a.startsWith('enhance-view-')){state.enhance.effect=a.slice(13);state.enhanceOpen=[...new Set([...(state.enhanceOpen||[]),state.enhance.effect])];}
  else if(a.startsWith('enhance-move-')){const e=state.enhance,id=a.slice(13),group=e.weapon.includes(id)?e.weapon:e.defence,i=group.indexOf(id),j=i===0?2:i-1;[group[i],group[j]]=[group[j],group[i]];e.effect=id;e.feedback=EnhancementModels.effects[id].name+'已前移；顺位门槛已更新，暂不生效的选择仍保留。';}
  else if(a==='enhance-branch-apply'){const e=state.enhance,g=e.weapon.includes(e.effect)?e.weapon:e.defence,gate=EnhancementModels.positions[g.indexOf(e.effect)].nodeGates[e.node];if(e.effective>=gate&&e.choice&&!(e.effect==='repeat'&&e.node===1&&e.choice==='B')){e.branches[e.effect][e.node]=e.choice;e.feedback=EnhancementModels.effects[e.effect].name+'节点'+(e.node+1)+'已选择'+e.choice+'。';goRoute('enhancement');return;}}
  else if(a==='galaxy-zoom-in'||a==='galaxy-zoom-out'){state.galaxyView.zoom=Math.max(.65,Math.min(2,state.galaxyView.zoom+(a.endsWith('in')?.15:-.15)));}
  else if(a==='galaxy-reset'){focusGalaxy();}
  else if(a==='galaxy-overview'){state.galaxyView={x:0,y:0,zoom:1.05};}
  else if(a==='galaxy-region'){openDetail('第一星系 · 区域一','区域内30设施槽。工程与升级自动调度；当前人员 '+crewCount('galaxy')+'/6。当前所看区域和节点保持。');return;}
  else if(a==='galaxy-effects'){const n=state.galaxyNodes[state.galaxyNode];openDetail(n.state==='fog'?'未探索节点':n.name,n.state==='fog'?'类型与效果尚未揭示。':galaxyEffect[n.family]+'；当前 '+(n.state==='complete'||n.state==='upgrading'?'Lv.'+n.level+'贡献生效':'尚未生效')+'。具体当前/完成后因子由星系展示模型提供，本画面不按美术等级重新推导收益。');return;}
  else if(a==='galaxy-crew') {state.crewDraft='galaxy';goRoute('crew');return;}
  else if(a==='crew-apply') {const reason=crewAdmission();if(reason){state.crewError=reason;}else{const m=state.crewMembers[state.crewId];
    const unchanged=m.job===state.crewDraft&&(!m.job.startsWith('planet-')||m.targetPlanet===state.crewPlanet)&&(m.job!=='planet-build'||m.targetFacility===state.crewFacility)&&(m.job!=='equipment'||m.mode===state.crewMode);
    state.crewError='';if(unchanged){notify('岗位与目标未变化；当前占用与任务进度保持');}
    else {Object.assign(m,{job:state.crewDraft,targetPlanet:state.crewPlanet,targetFacility:state.crewFacility,mode:state.crewMode});if(m.job==='planet-explore'){const p=state.planets.find(p=>p.id===m.targetPlanet);p.running=true;p.elapsed='0';p.duration=p.id==='1'?'60':'26';}syncDemoCrewTargets();notify('派遣已接纳，人物与对应目标人数同步');}
  }}
  else if(a==='crew-release') {if((state.hyperspaceTaskDesk?.autoEnabled&&state.hyperspaceTaskDesk.autoCrew===state.crewId)||(state.onlineTask.crewId===state.crewId&&['running','ready'].includes(state.onlineTask.status))){openDetail('当前成员被任务保留','先停止自动任务或解决待领回执，再释放当前人员。');return;}state.crewMembers[state.crewId].job='idle';syncDemoCrewTargets();notify('当前成员已释放，目标人数与缺人暂停状态更新');}
  else if(a==='crew-target') {if(state.crewDraft.startsWith('planet-')){state.planetId=state.crewPlanet;selectedPlanet().facilitySelection=state.crewFacility;}goRoute(state.crewDraft==='galaxy'?'galaxy':state.crewDraft==='idle'?'crew':state.crewDraft.startsWith('planet-')?'planet':state.crewDraft);return;}
  else if(a==='research-apply-iron'||a==='research-apply-uranium') {const iron=a==='research-apply-iron';const draft=iron?state.researchDraft:state.researchUraniumDraft;if(!validAmountDraft(draft)){state.researchError=(iron?'铁':'铀')+'投入需为非负整数金额；当前生效值保持，草稿可继续修正。';}else{if(iron)state.researchBudget=state.researchDraft;else state.researchUranium=state.researchUraniumDraft;state.researchError='';state.researchFeedback=(iron?'铁':'铀')+'投入已应用，另一资源与研究工作量保持。';notify('本资源投入已应用');}}

  else if(a==='research-budget-open') {state.researchBudgetOpen=true;}
  else if(a==='research-budget-close') {state.researchBudgetOpen=false;}
  else if(a==='research-select') {state.researchDrawer=true;}
  else if(a==='research-close') {state.researchDrawer=false;}
  else if(a==='research-reset') {state.researchDraft=state.researchBudget;state.researchUraniumDraft=state.researchUranium;state.researchCustom=true;state.researchError='';state.researchFeedback='草稿已还原为当前生效值。';}
  else if(a==='research-mode-once'||a==='research-mode-follow'){const next=a.endsWith('once')?'once':'follow';if(next===state.researchMode)return;state.researchModeRatios[state.researchMode]=state.researchIntent;state.researchMode=next;state.researchIntent=state.researchModeRatios[next];state.researchFeedback='已切换预算模式；本次金额草稿及各模式比例均保留，尚未应用。';}
  else if(a==='research-auto-stop'){state.researchAuto=false;state.researchAutoDraft=false;state.researchError='';state.researchFeedback='持续跟随已关闭（沿用已接纳的'+state.researchRatio+'%比例），当前已生效投入保持。';}
  else if(a==='research-intent-now') {const rows=budgetPreview(state.researchIntent);state.researchDraft=rows[0].rate;state.researchUraniumDraft=rows[1].rate;state.researchFeedback='即时预算草稿已生成，当前投入保持；铁和铀分别接纳，失败不撤销已成功资源。';}
  else if(a==='research-intent-auto') {if(!Number.isFinite(state.researchIntent)||state.researchIntent<0.1||state.researchIntent>100||budgetPreview(state.researchIntent,true)[0].rate===null){state.researchError='持续比例至少0.1%，当前设置保持；停止请关闭持续跟随。';render();return;}state.researchError='';state.researchAuto=true;state.researchAutoDraft=true;state.researchRatio=String(state.researchIntent);state.researchRatioDraft=String(state.researchIntent);state.researchFeedback='持续收入比例已设置；沿原刷新边界生效，不重置周期，当前投入保持。';}
  else if(a==='research-auto-apply') {if(!Number.isFinite(Number(state.researchRatioDraft))||Number(state.researchRatioDraft)<0.1||Number(state.researchRatioDraft)>100){state.researchError='持续比例需在0.1–100%以内，当前预算设置保持。';render();return;}state.researchAuto=state.researchAutoDraft;state.researchRatio=state.researchRatioDraft;state.researchFeedback='预算设置已接纳，沿原周期采用；当前投入金额保持。';}
  else if(a==='research-crew') {const assigned=Object.entries(state.crewMembers).find(([id,m])=>m.available&&m.job==='research');if(assigned)selectCrew(assigned[0]);else state.crewDraft='research';goRoute('crew');return;}
  else if(a==='equip-one'||a==='equip-ten'||a==='equip-max-mode') {state.equipmentMode=a==='equip-one'?'one':a==='equip-ten'?'ten':'max';state.candidate=false;}
  else if(a.startsWith('drone-pick-')) {const id=a.slice(11);state.droneId=id;state.droneSelection=state.droneSelection.includes(id)?state.droneSelection.filter(x=>x!==id):[...state.droneSelection,id];invalidateForge();}
  else if(a.startsWith('drone-detail-')) {state.droneId=a.slice(13);invalidateForge();goRoute('hyperspace/drone');return;}
  else if(a==='warehouse-formation') {state.formationDraft=[...state.droneSelection];state.formationPreview=null;state.formationError='';goRoute('hyperspace/formation');return;}
  else if(a==='warehouse-forge') {state.droneId=state.droneSelection[0];invalidateForge();goRoute('hyperspace/forge');return;}
  else if(a==='drone-to-formation') {state.formationDraft=[state.droneId];state.formationPreview=null;state.formationError='';goRoute('hyperspace/formation');return;}
  else if(a==='drone-to-forge') {invalidateForge();goRoute('hyperspace/forge');return;}
  else if(a==='formation-set') {state.formationDraft=[state.droneId];state.formationPreview=null;state.formationError='';}
  else if(a==='formation-preview') {state.formationPreview={equip:state.formationDraft.filter(id=>!state.equippedDrones.includes(id)),remove:state.equippedDrones.filter(id=>!state.formationDraft.includes(id))};}
  else if(a==='formation-confirm') {if(state.formationPreview){state.equippedDrones=[...state.formationDraft];state.formationPreview=null;notify('无人机编队已应用，普通舰体装备未改变');}}
  else if(a==='formation-cancel') {state.formationPreview=null;}
  else if(a==='warehouse-filter') {goRoute('hyperspace/filter');return;}
  else if(a==='warehouse-sealed') {goRoute('hyperspace/sealed');return;}
  else if(a==='drone-hanging') {goRoute('hyperspace/hanging');return;}
  else if(a==='drone-favorite') {goRoute('hyperspace/protection');return;}
  else if(a==='save-open') {goRoute('settings/save');return;}
  else if(a==='archive-tutorial'){goRoute('archive/tutorial');return;}
  else if(a==='tutorial-continue'){state.archive.guidePaused=false;notify('引导暂停已释放；其他暂停原因保持');}
  else if(a==='tutorial-target'){goRoute({equip:'equipment',upgrade:'equipment',pickup:'archive/statistics',retreat:'equipment',clear:'archive/notifications'}[state.archive.tutorial]);return;}
  else if(a==='settings-audio'){goRoute('settings/preferences');return;}
  else if(a==='save-directory-apply'){const m=state.maintenance;if(!m.directoryDraft.trim()){m.feedback='候选目录为空，当前目录保持。';}else{m.directory=m.directoryDraft;m.feedback='演示目录已切换，当前进度仍需请求保存。';m.save='dirty';}}
  else if(a==='save-picker'){openDetail('选择保存目录',`<label>目录<select id="directory-choice"><option>D:/SpaceIdle/save</option><option>D:/SpaceIdle/backup</option></select></label><p>选取后写入候选目录；应用后才切换当前目录。</p>${control('save-picker-use','选取此目录','primary')}`);return;}
  else if(a==='save-picker-use'){state.maintenance.directoryDraft=$('#directory-choice').value;$('#inspect-detail').close();notify('候选目录已选取，当前目录保持');}
  else if(a==='save-retry'){state.maintenance.save='queued';state.maintenance.feedback='正在等待保存；完成后将显示保存时间。';}
  else if(a==='save-backup'){state.maintenance.importSource='backup-02.json';state.dangerPreview=null;state.dangerResult=null;goRoute('settings/danger/import');return;}
  else if(a.startsWith('danger-')&&['reforge','import','new'].includes(a.slice(7))) {const kind=a.slice(7);state.dangerKind=kind;state.dangerPreview=null;state.dangerResult=null;goRoute('settings/danger/'+kind);return;}
  else if(a==='danger-preview') {const m=state.maintenance;state.dangerSource=state.dangerKind==='reforge'?selectedPlanet().name:state.dangerKind==='import'?m.importSource:m.newDirectory;m.dangerError='';if(state.dangerKind==='import'&&!['backup-02.json','backup-03.json'].includes(m.importSource)){state.dangerPreview=null;m.dangerError='此文件无法载入，当前进度与原文件保持。请选择有效备份。';render();return;}if(state.dangerKind==='new'&&!m.newDirectory.trim()){m.dangerError='目标目录为空，当前航程保持。';render();return;}state.dangerPreview={id:'preview-'+(++m.previewSerial),kind:state.dangerKind,source:state.dangerSource,planetId:state.planetId,retained:[...m.retained],lost:Object.keys(drones).filter(id=>!m.retained.includes(id)),clearSettings:m.clearSettings};state.dangerResult=null;}
  else if(a==='danger-confirm') {const p=state.dangerPreview,m=state.maintenance;if(dangerMatches(p,state.dangerKind,state.dangerSource)){
    state.dangerResult={...p,message:p.kind==='import'?'存档已载入，但尚未保存成功。':p.kind==='reforge'?p.source+'重铸已完成，星球与星系进度保留。':'新航程已开始，正在等待首次保存。',next:p.kind==='import'?'当前可以继续游玩；请腾出磁盘空间，或换目录后重试保存。旧有效存档仍保留。':'可继续航行；请到保存页查看保存是否完成。',technical:p.kind==='import'?'候选Session已替换；持久化失败，原有效文件保留。':'事务'+p.kind+' / '+p.id+'已接纳；持久化请求排队，尚未收到写盘完成。'};
    m.save=p.kind==='import'?'failed':'queued';m.feedback=p.kind==='import'?'存档已载入；磁盘空间不足，当前进度尚未保存。请重试或换目录，旧存档保留。':'新进度已启用，正在等待保存完成。';state.dangerPreview=null;notify('本次操作结果已保留；可查看保存状态');
  }}
  else if(a==='danger-cancel') {state.dangerPreview=null;notify('已取消预览，当前航程不变');}
  else if(a==='back') {back();return;}
  else if(a==='catalog') {goRoute('catalog');return;}
  else if(a==='expand') {state.collapsed=false;}
  else if(a==='close-detail') {$('#inspect-detail')?.close();return;}
  else {
    const details={'reactor-buy':['核心购级报价','核心 Lv.1 → Lv.2，本次费用10铀。新容量与分配结果由反应炉公开报价/实际模型提供，不由前端增长公式计算。'], 'galaxy-effects':['外环平台效果','当前Lv.2效果与目标Lv.3完成后的效果分别显示；升级完成自动接纳。'], 'galaxy-pan':['地图视角','当前区域一、外环平台仍选中；返回后视角保持。'], 'planet-detail':['轨道船坞','当前设施门槛、施工次数、实际人员与待领取状态。'], 'planet-other':['星球选择','当前起源星。切球只改变所看对象，不取消其探索或施工。']};
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
  else if(button.dataset.contextRoute) {const target=button.dataset.contextRoute;if(target==='crew'&&state.group==='hyperspace'&&(state.hyperspaceTaskDesk?state.hyperspaceTaskDesk.autoEnabled:state.onlineTask.crewId)){state.crewId=state.onlineTask.crewId;state.crewDraft=state.crewMembers[state.crewId].job;}goRoute(target.includes('/')?target:(state.moduleLast[target]||target));}
  else if(button.dataset.crew) {selectCrew(button.dataset.crew);render();}
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
  if(event.target.id==='research-intent'){state.researchIntent=Number(event.target.value);state.researchRatioDraft=String(state.researchIntent);state.researchModeRatios[state.researchMode]=state.researchIntent;if(state.researchMode==='once'){state.researchCustom=false;const rows=budgetPreview(state.researchIntent);state.researchDraft=rows[0].rate;state.researchUraniumDraft=rows[1].rate;}refreshBudgetControls();}

  if(event.target.id==='research-budget'){state.researchDraft=event.target.value;state.researchCustom=true;refreshBudgetControls();}
  if(event.target.id==='research-uranium'){state.researchUraniumDraft=event.target.value;state.researchCustom=true;refreshBudgetControls();}
  if(event.target.id==='research-ratio')state.researchRatioDraft=event.target.value;
  if(event.target.id==='danger-source') {state.dangerSource=event.target.value;state.dangerPreview=null;state.dangerResult=null;const preview=$('.transaction-preview');if(preview)preview.remove();notify('来源已改变，旧预览失效');}
  if(['save-directory','import-source','new-directory'].includes(event.target.id)){const key={'save-directory':'directoryDraft','import-source':'importSource','new-directory':'newDirectory'}[event.target.id];state.maintenance[key]=event.target.value;state.dangerPreview=null;state.dangerResult=null;document.querySelector('.transaction-preview')?.remove();document.querySelector('.danger-result')?.remove();}
  if(event.target.id==='exchange-amount'){state.workshop.exchangeAmount=event.target.value;const area=document.querySelector('.exchange-bench');const oldFocus=event.target.selectionStart;const box=document.createElement('div');box.innerHTML=HyperWorkshop.render('materials',state,drones,control,asset);area.outerHTML=box.querySelector('.exchange-bench').outerHTML;const field=document.querySelector('#exchange-amount');field.focus();field.setSelectionRange(oldFocus,oldFocus);}
  if(event.target.id==='preset-name')state.workshop.presetName=event.target.value;
  if(event.target.id==='material-amount') state.materialDraft=event.target.value;
  if(['research-budget','research-uranium'].includes(event.target.id)){const dirty=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium;const flag=$('.investment-title small');if(flag)flag.textContent=dirty?'草稿未应用，当前生效值保持':'当前投入已生效';const context=$('[data-context-route="research"] span');if(context)context.textContent=summary('research');const pending=$('.research-budget-state');if(pending)pending.textContent=state.researchDraft!==state.researchBudget||state.researchUraniumDraft!==state.researchUranium?'有未应用草稿':'已生效';}
});
document.addEventListener('change',event=>{
  const id=event.target.id,value=event.target.value;
  if(event.target.dataset.reactorShare!==undefined)render();
  if(id==='exchange-source'||id==='exchange-target'){state.workshop[id==='exchange-source'?'exchangeSource':'exchangeTarget']=value;state.workshop.exchangeReceipt='';render();}
  if(id==='danger-planet'){state.planetId=value;state.dangerPreview=null;state.dangerResult=null;render();}
  if(event.target.dataset.retainDrone){const id=event.target.dataset.retainDrone;state.maintenance.retained=event.target.checked?[...state.maintenance.retained,id]:state.maintenance.retained.filter(x=>x!==id);state.dangerPreview=null;state.dangerResult=null;render();}
  if(id==='new-clear-settings'){state.maintenance.clearSettings=event.target.checked;state.dangerPreview=null;render();}
  if(id.startsWith('pref-')){const m=state.maintenance;if(id==='pref-music')m.music=event.target.checked;if(id==='pref-effects')m.effects=event.target.checked;if(id==='pref-skip')m.skip=event.target.checked;if(id==='pref-damage')m.damage=value;if(id==='pref-interval'){if(/^\d+$/.test(value)&&Number(value)<=86400)m.interval=value;else m.feedback='自动保存间隔需为0–86400现实秒；原值保持。';}render();}
  if(id==='research-auto-toggle')state.researchAutoDraft=event.target.checked;
  if(id==='m2-batch-case'){const d=EquipmentWorkbench.ensure(state);d.batchContext=value;d.receipt=null;d.feedback='';if(['limited','failure'].includes(value)){HyperWorkshop.ensure(state,drones);state.workshop.materials.degenerate_matter='10';d.wallet=structuredClone(EquipmentResponseModels.wallet);d.mode=value==='failure'?'ten':'one';document.querySelector('#iron').textContent=d.wallet.iron;}render();}
  if(id==='m2-ships-case'){EquipmentWorkbench.ensure(state).unlocked=value==='all';render();}
  if(id==='planet-select'){state.planetId=value;state.planet=selectedFacility().state;notify('已切换所看星球，各星球任务保持');render();}
  if(id==='crew-target') {state.crewDraft=value;state.crewError='';render();}
  if(id==='crew-planet'){state.crewPlanet=value;state.crewFacility=state.planets.find(p=>p.id===value).facilitySelection;render();}
  if(id==='crew-facility'){state.crewFacility=value;render();}
  if(id==='crew-mode'){state.crewMode=value;render();}
  if(id==='forge-operation') {state.forgeOperation=value;invalidateForge();render();}
});
$('#collapse').onclick=()=>{rememberScroll();state.collapsed=!state.collapsed;render();};
$('#pause').onclick=()=>{state.paused=!state.paused;notify(state.paused?'已暂停，界面仍可查看':'航程已恢复');render();};
$('#scenario-open').onclick=()=>$('#scenario').showModal();
$('#scenario-close').onclick=()=>$('#scenario').close();
$('#assembly-toggle').onclick=()=>{document.body.classList.toggle('show-assembly');$('#assembly-toggle').classList.toggle('active',document.body.classList.contains('show-assembly'));};
for(const key of ['reactor','equipment','planet','galaxy']) $('#'+key+'-case').onchange=event=>{
  if(key==='planet'){loadPlanetFixture(event.target.value);render();return;}
  state[key]=event.target.value;if(key==='reactor'){state.reactorIntent='custom';state.reactorReceipt='';}
  if(key==='reactor') {state.actual=event.target.value==='idle'?[0,0,0,0]:[45,35,20,0];state.alloc=event.target.value==='draft'?[60,35,5,0]:event.target.value==='rejected'?[55,35,20,0]:[...state.actual];state.reactorError=event.target.value==='rejected'?'额度不足，实际供能保持原值。':'';}
  if(key==='galaxy'){const n=state.galaxyNodes[state.galaxyNode];n.state=event.target.value;n.progress=n.state==='complete'?100:n.state==='building'?62:n.state==='upgrading'?48:0;n.level=n.state==='upgrading'?2:n.state==='complete'?3:1;}

  if(key==='equipment'){if(event.target.value==='poor'){const d=EquipmentWorkbench.ensure(state);d.wallet=structuredClone(EquipmentResponseModels.poorWallet);if(state.workshop)state.workshop.materials.degenerate_matter=d.wallet.material;document.querySelector('#iron').textContent=d.wallet.iron;}state.candidate=event.target.value==='compare';state.cooldowns=event.target.value==='cooldown'?{[state.slot]:10}:{};if(event.target.value==='cooldown')state.equipment='normal';}
  render();
};
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
document.addEventListener('pointermove',e=>{if(!cityDrag||e.pointerId!==cityDrag.id)return;const d=cityDrag,dx=e.clientX-d.x,dy=e.clientY-d.y;if(Math.hypot(dx,dy)>6)d.moved=true;if(!d.moved)return;window.cityDragged=true;const rect=d.map.getBoundingClientRect(),scale=Math.max(800/rect.width,550/rect.height);state.galaxyView.x=d.origin.x+dx*scale;state.galaxyView.y=d.origin.y+dy*scale;const v=state.galaxyView;$('#city-transform')?.setAttribute('transform',`translate(${v.x} ${v.y}) translate(400 270) scale(${v.zoom}) translate(-400 -270)`);});
document.addEventListener('pointerup',()=>{cityDrag=null;});
document.addEventListener('wheel',e=>{if(!e.target.closest('.city-map'))return;e.preventDefault();state.galaxyView.zoom=Math.max(.65,Math.min(2,state.galaxyView.zoom+(e.deltaY<0?.1:-.1)));render();},{passive:false});
