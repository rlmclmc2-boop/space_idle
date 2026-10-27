/* Frozen layout experiment. Fixed facts only; no game state or simulation. */
const worldDraft={facility:'shipyard',automatic:true,galaxyNode:'n3',pan:[0,0],zoom:1};
const worldFacts={
 station:{name:'空间站',icon:'auto_explore',status:'已领取',benefit:'自动探索已开放',threshold:'探索度1',progress:'1 / 1'},
 refinery:{name:'精炼厂',icon:'refinery',status:'已领取',benefit:'铁、铀原生掉落增益 ×1.32',threshold:'探索度20',progress:'5 / 5'},
 workshop:{name:'装备工坊',icon:'equipment',status:'已领取',benefit:'普通装备属性增益 ×1.38',threshold:'探索度50',progress:'10 / 10'},
 shipyard:{name:'船坞',icon:'shipyard',status:'施工中',benefit:'领取后开放本星球征服/重铸入口',threshold:'探索度30',progress:'84 / 180'}
};
const cityFacts={
 hq:{name:'总部',level:'—',effect:'总部不占功能建筑槽',bonus:'—'},
 n1:{name:'居住环',level:'2',effect:'船员经验因子',bonus:'+0.20'},
 n2:{name:'星际精炼厂',level:'2',effect:'铁自动收入比例',bonus:'+0.10'},
 n3:{name:'轨道船坞',level:'2',effect:'装备属性因子',bonus:'+0.20'},
 n4:{name:'恒星能源阵列',level:'2',effect:'反应炉容量因子',bonus:'+0.20'},
 n5:{name:'晶体精炼厂',level:'2',effect:'强化碎片因子',bonus:'+0.20'},
 n6:{name:'重元素精炼厂',level:'2',effect:'铀自动收入比例',bonus:'+0.10'},
 n7:{name:'居住环',level:'1',effect:'船员经验因子',bonus:'+0.10'}
};
const cityAnchors={hq:[800,473.82],n1:[242.76,475.85],n2:[499.16,688.92],n3:[916,787.28],n4:[466.09,272.13],n5:[1214.13,618.16],n6:[821.41,164.89],n7:[1200.58,304.86]};
Object.assign(state,{planet:'exploring',galaxy:'construction'});
Object.assign(scenarios,{
 planet:[['exploring','探索 / 船坞施工'],['missing','缺施工人员'],['ready','船坞待领取'],['claimed','船坞已领取'],['stopping','本次完成后停止'],['cancelled','立即取消后']],
 galaxy:[['construction','节点施工中'],['missing','缺星系人员'],['active','节点自动建成'],['upgrading','保留当前级升级'],['fog','尚未探索节点']]
});
function planetDraft(){
 const mode=state.planet,id=worldDraft.facility,f=worldFacts[id],shipyard=id==='shipyard';
 const cancelled=mode==='cancelled',missing=mode==='missing',ready=shipyard&&mode==='ready',claimed=!shipyard||mode==='claimed';
 const status=claimed?'已领取':ready?'待领取':missing?'缺人暂停':'施工中';
 return `<div class="w-room w-planet"><div class="w-head"><span class="eyebrow">PLANET / ORBITAL EXPLORATION</span><h2>始源星</h2><p>探索度126 · 本轮尚未征服</p></div>
  <div class="w-orbit"></div><img class="w-globe" alt="现有始源星贴图离线球体预览" src="world/assets/origin-planet-preview.png">
  ${[['station','f-station'],['refinery','f-refinery'],['workshop','f-workshop'],['shipyard','f-shipyard']].map(([key,cls])=>`<button data-facility="${key}" class="w-facility ${cls} ${id===key?'active':''} ${key==='shipyard'&&mode!=='claimed'?'unclaimed':''}"><img src="../../assets/planets/orbital/models/${worldFacts[key].icon}-icon.png" alt=""><span>${worldFacts[key].name} · ${key==='shipyard'?(mode==='claimed'?'已领取':mode==='ready'?'待领取':'施工中'):'已领取'}</span></button>`).join('')}
  <section class="w-console w-side"><img src="../../assets/planets/orbital/models/${f.icon}-icon.png" alt="所选${f.name}"><div class="split"><h3>${f.name}</h3><span class="tag">${status}</span></div><dl><div><dt>开放门槛</dt><dd>${f.threshold}</dd></div><div><dt>累计施工</dt><dd>${shipyard&&(ready||claimed)?'180 / 180':f.progress}次探索</dd></div><div><dt>额外施工人员</dt><dd>${shipyard?(missing?'0 / 1':'1 / 1'):'无需额外人员'}</dd></div></dl><h4>${claimed?'当前收益':'领取后收益'}</h4><p>${f.benefit}</p>${!claimed?'<p class="small muted">尚未生效</p>':''}
   ${ready?'<button class="primary" id="claim-planet">领取船坞</button>':missing&&shipyard?statusBlock('warning','缺少1名额外施工人员；累计84次保留。')+'<button id="planet-staff">查看人员需求</button>':claimed&&shipyard?statusBlock('success','船坞已领取，征服入口已开放。'):shipyard?'<p class="small muted">后续探索完成时推进施工</p>':''}
   <div class="w-section"><button id="planet-buffs">累计加成</button><button id="planet-reforge" ${mode!=='claimed'?'disabled':''}>征服 / 重铸</button></div>
  </section>
  <section class="w-console w-bottom"><div class="split"><h3>探索队 · ${cancelled?'待命':paused?'已暂停':'高坚果'}</h3><span class="w-status">${cancelled?'未开始':mode==='stopping'?'本次完成后停止':paused?'暂停':'探索中'}</span></div><p>${cancelled?'本次进度0，探索者已释放；既有探索度与施工累计保留。':'本次28 / 60游戏秒 · 完成经验 +1.20K'}</p><div class="progress"><i style="width:${cancelled?'0':'47'}%"></i></div><div class="actions"><button id="planet-auto" ${cancelled?'disabled':''}>自动探索：${mode==='stopping'||!worldDraft.automatic?'关闭':'开启'}</button><button id="planet-cancel" ${cancelled?'disabled':''}>立即取消本次</button><select aria-label="星球导航"><option>始源星 · 当前</option><option disabled>气态巨星 · 尚未开放</option></select></div></section>
 </div><p class="w-note">封存布局试验：现有贴图/设施图标用于安装关系；离线球体不替代planet_visual及其独立云层。数值为固定样例，未领取设施不显示收益生效。最终视觉方向尚未确定。</p>`;
}
function galaxyDraft(){
 const mode=state.galaxy,id=worldDraft.galaxyNode,f=cityFacts[id];
 const selected=id==='n3';const foundation=selected&&['construction','missing','fog'].includes(mode);
 const status=foundation?(mode==='missing'?'缺人暂停':mode==='fog'?'未探索':'施工中'):selected&&mode==='upgrading'?'升级中':'已建成';
 const progress=foundation?(mode==='fog'?'未开始':'施工14 / 30游戏秒'):selected&&mode==='upgrading'?'Lv.2 → 3 · 工作量180 / 540':'当前级生效';
 return `<div class="w-room w-galaxy"><div class="w-head"><span class="eyebrow">GALAXY / ORBITAL CITY</span><h2>第一星系 · ${mode==='upgrading'?'发展中':'探索建设中'}</h2><p>实际人员${mode==='missing'?'0':'2'} / 6 · 下方仅为8对象布局样本，非完整30槽蓝图</p></div>
  <div class="w-city-viewport" id="city-viewport"><svg id="city-canvas" viewBox="0 0 1600 1000" preserveAspectRatio="xMidYMid meet" style="transform:translate(${worldDraft.pan[0]}px,${worldDraft.pan[1]}px) scale(${worldDraft.zoom})"><image href="world/assets/${['construction','missing','fog'].includes(mode)?'galaxy-foundation':'galaxy-developed'}.png" width="1600" height="1000"/>
   ${Object.entries(cityAnchors).map(([key,[x,y]])=>`<g class="city-pick ${id===key?'selected':''}" data-city-node="${key}" tabindex="0" role="button" aria-label="查看${cityFacts[key].name}" transform="translate(${x},${y})"><circle r="29"/><text text-anchor="middle" y="9">${key==='hq'?'总':key.slice(1)}</text></g>`).join('')}
   ${mode==='fog'?'<path d="M790 700h250v190H790z" fill="#264858bb" stroke="#a6b9b0" stroke-dasharray="12 10"/>':''}
  </svg></div>
  <section class="w-console w-side"><div class="split"><h3>${f.name}</h3><span class="tag">${status}</span></div><p>对象 ${id.toUpperCase()} · ${id==='hq'?'独立总部':'功能节点'}</p><dl><div><dt>当前等级</dt><dd>${foundation?'—':f.level}</dd></div><div><dt>可达性</dt><dd>${mode==='fog'&&selected?'父节点尚未探索':'可达'}</dd></div><div><dt>进度</dt><dd>${progress}</dd></div></dl><h4>${foundation?'建成后效果（尚未生效）':'当前生效效果'}</h4><p>${f.effect} ${foundation?'+0.10':f.bonus}</p>${mode==='upgrading'&&selected?'<p>当前Lv.2效果保留；完成后再更新等级与模型。</p>':''}
   ${mode==='missing'&&selected?statusBlock('warning','星系岗位无人，当前工作量保留。'):mode==='active'&&selected?statusBlock('success','节点已自动建成，当前效果已生效。'):mode==='fog'&&selected?statusBlock('neutral','尚未可达，探索工作未开始。'):''}
   <button id="galaxy-staff">查看星系人员</button><p class="small muted">建设与升级自动完成</p>
  </section>
  <div class="w-map-tools"><button id="city-out" aria-label="缩小星系">−</button><button id="city-home">复位视角</button><button id="city-in" aria-label="放大星系">＋</button></div><p class="w-map-caption">${mode==='upgrading'?'当前级模型保留，未提前显示升级结果。':'现有GLB离线安装样本；桥与平台布局不是运行蓝图。'}</p>
 </div><p class="w-note">封存布局试验：最终接入继续使用现galaxy_map和真实节点快照；本图不改工作量、RNG、父节点可达性或交通规则，不新增领取。预览的样本节点不等于满城。</p>`;
}
const priorWorldRender=render;
render=function(){
 priorWorldRender();
 if(active==='planet'||active==='galaxy'){
  $('#module-body').innerHTML=active==='planet'?planetDraft():galaxyDraft();
  $('.review-bar>span').textContent='封存布局试验 · 仅接口/操作摆放候选 · 不冻结视觉框架 · 固定样例';
  bindWorldDraft();
 }
};
const priorWorldPause=$('#pause').onclick;
$('#pause').onclick=()=>{priorWorldPause();if(active==='planet'||active==='galaxy')render();};
function bindWorldDraft(){
 document.querySelectorAll('[data-facility]').forEach(b=>b.onclick=()=>{worldDraft.facility=b.dataset.facility;render();});
 $('#claim-planet')?.addEventListener('click',()=>{state.planet='claimed';render();});
 $('#planet-auto')?.addEventListener('click',()=>{worldDraft.automatic=!worldDraft.automatic;state.planet=worldDraft.automatic?'exploring':'stopping';render();});
 $('#planet-cancel')?.addEventListener('click',()=>{state.planet='cancelled';render();});
 $('#planet-staff')?.addEventListener('click',()=>openDialog('人员需求','<p>船坞额外施工人员0 / 1。探索者高坚果继续当前探索；需另派1名空闲船员。当前累计施工84次保留。</p><p>船员派遣细稿尚未展开，本批封存，不在此直接改派。</p>'));
 $('#planet-buffs')?.addEventListener('click',()=>openDialog('当前已生效加成','<p>精炼厂：铁、铀原生掉落 ×1.32。</p><p>装备工坊：普通装备属性 ×1.38。</p><p>本星球尚未征服，没有本星球的永久征服奖励。</p>'));
 $('#planet-reforge')?.addEventListener('click',()=>openDialog('征服 / 重铸入口 · 尚未展开','<p>此入口接既有预览/确认事务。本批仅封存星球/星系布局样本，尚未交付重铸细稿，不执行任何操作。</p>'));
 const choose=id=>{worldDraft.galaxyNode=id;render();};
 document.querySelectorAll('[data-city-node]').forEach(g=>{g.onclick=()=>{if(!worldDraft.dragged)choose(g.dataset.cityNode);};g.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();choose(g.dataset.cityNode);}};});
 $('#city-in')?.addEventListener('click',()=>{worldDraft.zoom=Math.min(1.6,worldDraft.zoom+.15);render();});
 $('#city-out')?.addEventListener('click',()=>{worldDraft.zoom=Math.max(.7,worldDraft.zoom-.15);render();});
 $('#city-home')?.addEventListener('click',()=>{worldDraft.zoom=1;worldDraft.pan=[0,0];render();});
 $('#galaxy-staff')?.addEventListener('click',()=>openDialog('星系岗位人员','<p>当前星系人员'+(state.galaxy==='missing'?'0':'2')+' / 6。人员调整须使用Crew公开派遣操作。</p><p>本批未展开船员细稿，不从地图直接修改占用。</p>'));
 const viewport=$('#city-viewport');
 if(viewport){let down=null;viewport.onpointerdown=e=>{down=[e.clientX,e.clientY,...worldDraft.pan];worldDraft.dragged=false;};viewport.onpointermove=e=>{if(down&&(e.buttons&1)){const dx=e.clientX-down[0],dy=e.clientY-down[1];if(Math.hypot(dx,dy)>5){worldDraft.dragged=true;worldDraft.pan=[down[2]+dx,down[3]+dy];$('#city-canvas').style.transform=`translate(${worldDraft.pan[0]}px,${worldDraft.pan[1]}px) scale(${worldDraft.zoom})`;}}};viewport.onpointerup=()=>{down=null;setTimeout(()=>worldDraft.dragged=false,0);};viewport.onpointerleave=()=>{down=null;};}
}
if(!query.has('module'))active='planet';render();
