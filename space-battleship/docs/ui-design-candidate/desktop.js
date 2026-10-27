const $ = s => document.querySelector(s);
const modules = [['equipment','舰装','SHIP / DOCK'],['reactor','反应炉','POWER / ENGINE ROOM'],['research','科研','AI / WORKSHOP'],['enhancement','强化','EFFECT / SEQUENCE'],['crew','船员','CREW / ASSIGNMENT'],['planet','星球','PLANET / ORBIT'],['galaxy','星系','GALAXY / CITY'],['hyperspace','超空间','ROUTE / DRONE']];
function escapeAttr(value){return String(value).replaceAll("&","&amp;").replace(/"/g,"&quot;").replaceAll("<","&lt;").replaceAll(">","&gt;");}
const query = new URLSearchParams(location.search);
let active = modules.some(m => m[0] === query.get('module')) ? query.get('module') : 'reactor';
let paused = false, guarded = false, previousFocus;
const state = {reactor:'running',research:'running',equipment:'compare',slot:'W1',candidate:'upgrade',investmentOpen:false,selectedResearch:false,ironDraft:"120",uraniumDraft:"2",terminalMode:null,manualActual:{iron:"100",uranium:"2"},investMessages:{iron:{type:"neutral",text:"草稿120，尚未应用。"},uranium:{type:"neutral",text:"与当前设置一致。"}},autoActual:{enabled:false,ratio:"20"},autoDraft:{enabled:false,ratio:"20"},autoMessage:{type:"neutral",text:"与当前设置一致。"},equipmentNotice:true};
const scenarios = {
  reactor:[['running','有免费量 / 工作中'],['invalid','单设备非法草稿'],['stopped','单设备零有效供能']],
  research:[['running','工作中'],['paused','暂停'],['complete','完成'],['choice','选择其他研究'],['automatic','自动投入草稿'],['partial','单资源分别回执']],
  equipment:[['compare','当前 / 候选比较'],['cooldown','换装冷却'],['insufficient','费用不足'],['success','成功回执']]
};
function openDialog(title,body){previousFocus=document.activeElement;$('#dialog-title').textContent=title;$('#dialog-body').innerHTML=body;$('#dialog').hidden=false;$('#close-dialog').focus();}
function closeDialog(){$('#dialog').hidden=true;previousFocus?.focus();}
$('#close-dialog').onclick=closeDialog;
$('#dialog').onkeydown=e=>{if(e.key==='Escape'){e.preventDefault();closeDialog();}if(e.key==='Tab'){e.preventDefault();$('#close-dialog').focus();}};
const deviceArt = {
  weapons:`<svg viewBox="0 0 180 160" aria-label="武器供能设备结构占位"><g stroke="#375966" stroke-width="4" stroke-linejoin="round"><path fill="#e8eadc" d="M30 127v-21h120v21l-15 14H45z"/><path fill="#a1c3bd" d="M50 105V52l40-19 40 19v53z"/><path fill="#ececde" d="M32 73l23-34 45 5 18 31-14 32H52z"/><circle fill="#345c6b" cx="76" cy="72" r="24"/><circle fill="#92cfbf" cx="76" cy="72" r="13"/><path fill="#d3e2d5" d="M104 57h51v29h-51z"/><path d="M119 58v28m12-28v28m12-28v28" fill="none"/></g></svg>`,
  defence:`<svg viewBox="0 0 180 160" aria-label="防御供能设备结构占位"><g stroke="#375966" stroke-width="4"><path fill="#e8eadc" d="M25 125h130l-14 16H39z"/><path fill="#90b7b2" d="M40 120V75h22v45m56 0V75h22v45"/><ellipse fill="#e8eadc" cx="90" cy="71" rx="47" ry="53"/><ellipse fill="#2d5264" cx="90" cy="71" rx="32" ry="39"/><path d="M70 58l20-12 20 12v24L90 94 70 82z" fill="#9bcfc1"/><path d="M90 46v48M70 58l40 24M70 82l40-24" fill="none" stroke-width="2"/></g></svg>`,
  smelting:`<svg viewBox="0 0 180 160" aria-label="炼铁供能设备结构占位"><g stroke="#375966" stroke-width="4" stroke-linejoin="round"><path fill="#e8eadc" d="M25 125h130l-13 16H38z"/><path fill="#9bbdb4" d="M57 35h67v88H57z"/><path fill="#e9ead9" d="M50 20h81l-10 22H60z"/><rect x="47" y="55" width="85" height="62" rx="10" fill="#e8eadc"/><rect x="61" y="69" width="57" height="34" rx="4" fill="#305362"/><path d="M70 80h40m-40 12h40" stroke="#cfad76"/><path d="M132 65h17v43h-17" fill="#99bdb7"/></g></svg>`
};
for(const id of Object.keys(deviceArt)){
  deviceArt[id]=deviceArt[id].replace(/(<g[^>]*>)/, '$1<path fill="#a1c3bd" d="M0 72h58v16H0z"/>');
}
function reactorView(){
  const stopped=state.reactor==='stopped';
  return `<div class="reactor-room">
    <svg class="reactor-routes" viewBox="0 0 1000 740" preserveAspectRatio="none" aria-hidden="true">
      <path d="M90 690H950M90 670H950" fill="none" stroke="#b0c3b9" stroke-width="2"/>
      ${['casing','inner','energy'].map(cls=>`<path class="${cls}" d="M310 319H440V127H520M440 319V586H520M440 357H520"/>`).join('')}
      <g fill="#e9ead9" stroke="#365966" stroke-width="4"><rect x="302" y="305" width="23" height="28" rx="5"/><rect x="431" y="305" width="18" height="28" rx="4"/></g>
    </svg>
    <div class="core-label"><span class="eyebrow">POWER SOURCE</span><h2>反应炉 · Lv.6</h2><p>主供能核心 · 结构占位</p></div>
    <div class="core-install"><div class="core-orb"></div></div>
    <div class="core-console"><div class="split"><span>手动分配池</span><strong>600</strong></div><p class="small muted">已分配450 · 剩余150</p><button class="primary" data-info="购级先检查现有业务报价与结果，成功后重读容量；本稿不提交。">升级1级 · 45铀</button><div class="actions"><button class="compact" data-info="均分映射现有distribute；没有全体清零命令。">均分</button><span class="small muted">免费量不占预算</span></div></div>
    ${[['weapons','武器','伤害 +84%','200','40','240'],['defence','防御','盾甲容量 +56%','150','10','160'],['smelting','炼铁','铁产出 +32%','100','0','100']].map(([id,name,effect,manual,free,effective])=>{
      const off=stopped&&id==='smelting';const invalid=state.reactor==='invalid'&&id==='weapons';
      return `<section class="device-group ${id}" data-device="${id}"><div class="device-install">${deviceArt[id]}<span>未定稿 / 安装占位</span></div><div class="device-terminal"><div class="split"><h3>${name}</h3><span class="small">${off?'停机':'供能中'}</span></div><p class="effect">${off?'铁产出 +0%':effect}</p><p>实际手动 ${off?'0':manual} · 免费 ${free}<br>有效供能 ${off?'0':effective}</p><label for="allocation-${id}">手动分配草稿</label><div class="actions"><input id="allocation-${id}" data-input="${id}" value="${invalid?'abc':off?'0':manual}" aria-label="${name}分配草稿"><button data-apply="${id}">应用</button><button data-clear="${id}" aria-label="清零${name}手动分配">清零</button></div><p class="device-feedback ${invalid?'error':''}" id="feedback-${id}" aria-live="polite">${invalid?'请输入非负整数；实际200保持不变。':'已同步 · 无未提交更改'}</p></div></section>`;
    }).join('')}
  </div><p class="scene-note">待审：核心/三种设备等量级布置，共用安装平面与连续管路。造型只是结构占位；管口和效果包络仍需正式元数据核对。未开放碎片凝聚整套隐藏。</p>`;
}
function statusBlock(type,text,id=''){
  const symbol={neutral:'○',success:'✓',error:'!',warning:'◷'}[type]||'○';
  return `<p ${id?`id="${id}"`:''} class="feedback ${type}" aria-live="polite"><b class="feedback-symbol" aria-hidden="true">${symbol}</b><span>${text}</span></p>`;
}
function researchView(){
  const mode=state.research;const complete=mode==='complete',halt=mode==='paused'||paused,choice=mode==='choice';
  const actual=state.manualActual,auto=state.autoActual;
  return `<div class="lab ${choice?'choosing':''}">
    <img class="lab-background" alt="工厂背景" src="../../assets/ai_tech_factory/workshop-background-v2.png">
    <img class="lab-machine" alt="当前研究设备试装" src="../../assets/ai_tech_factory/weapon-accuracy-v2.png">
    ${!complete?'<img class="lab-probe" alt="独立探针" src="../../assets/ai_tech_factory/inspection-probe-v2.png">':''}
    <div class="lab-identity"><span class="tag">${complete?'本次研究已完成':halt?'已暂停':'当前实际研究'}</span><h2 style="margin-top:9px">武器精准 · Lv.${complete?'13':'12'}</h2><p>当前生效效果 +${complete?'30':'24'}%</p><p class="small">${complete?'本次提升 +6%':'下一等级效果 +30% · 提升6%'}</p></div>
    <div class="lab-work"><div class="split"><b>${complete?'100% · 完成':halt?'62% · 暂停':'62% · 研究中'}</b><span class="small">${complete?'100K / 100K':'62K / 100K'} 工作量</span></div><div class="progress"><i style="width:${complete?'100':'62'}%"></i></div><p>${complete?'等级与效果已更新；示例未自动续研':halt?'工作量保持 · 恢复后预计38秒':'速度1.24K/秒 · 预计剩余38秒'}</p></div>
    ${!choice?`<div class="lab-terminal"><h3>工厂终端</h3><p class="actual-investment">当前有效投入：铁${actual.iron}/秒 · 铀${actual.uranium}/秒</p><p>自动投入：${auto.enabled?'开启':'关闭'} · 共同预算 ${auto.ratio}%</p><p class="crew-status">续研岗位：1人 · 开启</p><div class="actions"><button id="investment-toggle">${state.terminalMode==='manual'?'收起手动':'手动投入'}</button><button id="automatic-toggle">${state.terminalMode==='automatic'?'收起自动':'自动设置'}</button><button id="research-choose">选择研究</button></div>
      ${state.terminalMode==='manual'?`<div class="terminal-fields"><h4>逐资源投入</h4>${[['iron','铁'],['uranium','铀']].map(([id,name])=>`<section class="resource-editor" data-resource="${id}"><label for="${id}">${name} / 游戏秒 · 当前 <strong>${actual[id]}</strong></label><div class="resource-input"><input id="${id}" value="${escapeAttr(state[id+'Draft'])}" aria-label="${name}投入草稿"><button data-invest-apply="${id}">应用${name}</button><button data-invest-reset="${id}" class="compact">还原</button></div>${statusBlock(state.investMessages[id].type,state.investMessages[id].text,'investment-feedback-'+id)}</section>`).join('')}</div>`:''}
      ${state.terminalMode==='automatic'?`<div class="terminal-fields automatic-editor"><h4>自动投入设置</h4><p>当前设置：${auto.enabled?'开启':'关闭'} · ${auto.ratio}%</p><label class="checkbox-label"><input id="auto-enabled" type="checkbox" ${state.autoDraft.enabled?'checked':''}>草稿：开启自动投入</label><label for="auto-ratio">铁、铀共同预算比例 · 草稿%</label><div class="resource-input"><input id="auto-ratio" value="${escapeAttr(state.autoDraft.ratio)}" inputmode="decimal"><button id="apply-automatic">应用设置</button><button id="reset-automatic" class="compact">还原</button></div>${statusBlock(state.autoMessage.type,state.autoMessage.text,'automatic-feedback')}<p class="budget-timing">岗位有人且自动投入开启时，每60游戏秒按近期收入与共同预算比例刷新铁、铀投入。应用开关/比例不立即重算当前有效投入。</p></div>`:''}
    </div>`:''}
    ${choice?`<aside class="research-selector"><h3>切换研究</h3><p class="small muted">当前仍在研究武器精准，62K / 100K。</p><div class="research-options"><button class="${state.selectedResearch?'':'selected'}" data-research="current">武器精准 · 当前<br><span class="small">Lv.12 · 已完成62%</span></button><button class="${state.selectedResearch?'selected':''}" data-research="candidate">一体化 · 候选<br><span class="small">Lv.3 · 已完成18%</span></button></div>${state.selectedResearch?`<section class="candidate-facts"><h4>候选 · 一体化 Lv.3 → 4</h4><dl><div><dt>当前生效效果</dt><dd>联合增益 ×1.10</dd></div><div><dt>下一等级效果</dt><dd>联合增益 ×1.15</dd></div><div><dt>已保留工作量</dt><dd>18K / 100K · 18%</dd></div><div><dt>切换后预计余时</dt><dd>66秒（示例）</dd></div></dl><p>切换后从18K继续；武器精准的62K保留。任一时刻仅推进当前研究。</p><button class="primary" id="confirm-research">确认切换（示例）</button></section>`:'<p>当前项目将继续研究；选择候选可查看效果和已保留工作量。</p>'}<button id="close-research">取消选择</button></aside>`:''}
  </div><p class="scene-note">固定样例：效果、工作量和预计时间不是配置正确性证明。当前研究与候选分离；自动投入设置和岗位续研分别显示，铁/铀通过既有单资源端口独立应用。</p>`;
}
const slotData={W1:{name:'武器槽01',type:'舰炮',value:'12.6K',next:'14.2K',property:'单次伤害'},W2:{name:'武器槽02',type:'脉冲',value:'8.4K',next:'9.5K',property:'单次伤害'},W3:{name:'武器槽03',type:'导弹',value:'6.2K',next:'7.0K',property:'单次伤害'},D1:{name:'防御槽01',type:'复合装甲',value:'8.0K',next:'9.1K',property:'最大容量'},D2:{name:'防御槽02',type:'护盾',value:'12.0K',next:'13.6K',property:'最大容量'}};
function equipmentView(){
  const slot=slotData[state.slot],mode=state.equipment,success=mode==='success',replace=state.candidate==='replace';
  const candidate=replace?(state.slot.startsWith('D')?'护盾':'长激光'):slot.type;
  const currentType=success&&replace?candidate:slot.type;
  const currentLevel=success&&!replace?'20':'19';
  const comparison=`<label class="small" for="candidate">候选操作</label><select id="candidate"><option value="upgrade" ${replace?'':'selected'}>购级 · 当前装备升1级</option><option value="replace" ${replace?'selected':''}>换装 · ${state.slot.startsWith('D')?'护盾':'长激光'}候选</option></select><p class="selection-line">预览目标：${state.slot} · ${replace?'换装':'购级1级'}</p>
    <table class="compare-table"><thead><tr><th>属性</th><th>当前</th><th>候选</th></tr></thead><tbody><tr><td>装备</td><td>${currentType}</td><td>${candidate}</td></tr><tr><td>槽位等级</td><td>19</td><td>${replace?'19':'20'}</td></tr><tr><td>${replace&&!state.slot.startsWith('D')?'主属性（异口径）':slot.property}</td><td>${replace&&!state.slot.startsWith('D')?'单次 ':''}${slot.value}</td><td>${replace&&!state.slot.startsWith('D')?'持续 ':''}${slot.next}${replace&&!state.slot.startsWith('D')?'/秒':''}</td></tr><tr><td>冷却</td><td>1.2秒</td><td>${replace?'2.0秒':'1.2秒'}</td></tr></tbody></table>
    <div class="quote"><strong>本次费用</strong><p>${replace?'换装报价等待真实端口接入':'铁2.4K · 简并物质10'}</p><p class="small ${mode==='insufficient'?'':'muted'}">${mode==='insufficient'?'缺少简并物质4；当前拥有6':'余额与合法性由业务返回'}</p></div>
    <button class="commit primary" id="equipment-commit" ${mode==='cooldown'?'disabled':''}>${mode==='cooldown'?'换装冷却中 · 2.6秒':replace?'确认换装（示例）':'购买1级（示例）'}</button>
    ${statusBlock(mode==='insufficient'?'error':mode==='cooldown'?'warning':'neutral',mode==='insufficient'?'未提交：缺少简并物质4，选择与草稿保持。':mode==='cooldown'?'冷却中：剩余2.6秒，选择与候选保持。':'预览就绪 · 尚未提交。','equipment-feedback')}`;
  const completed=`<section class="completed-transaction" data-transaction="closed"><h3>本次预览已结束</h3><p class="small muted">当前${slot.property}：${slot.next}${replace&&!state.slot.startsWith('D')?'/秒':''}</p>${state.equipmentNotice?statusBlock('success',replace?'已完成换装（示例），槽位等级保留。':'已完成购级（示例）：Lv.19 → 20。','equipment-feedback'):''}<details class="receipt-record"><summary>已完成回执 · ${state.slot}</summary><p>${replace?`${slot.type} → ${candidate}；等级19保持`:'等级19 → 20'}</p><p>${replace?'替换前后属性口径分别记录':`${slot.property} ${slot.value} → ${slot.next}`}</p><p>${replace?'换装结果为固定样例':'本次已支付：铁2.4K · 简并物质10'}</p></details><div class="next-preview-status"><strong>没有可提交的下一次预览</strong><p>下一次目标与报价须重新读取后再开放操作。</p></div></section>`;
  return `<div class="dock"><div class="dock-floor"></div><div class="dock-identity"><h2>巡洋舰 · 当前舰</h2><p>当前启用 · 示例3武器 / 2防御</p></div>
    <div class="ship-wrap"><img alt="巡洋舰当前预览" src="../../assets/ui/ships/fleet_20261019/03-cruiser.png">${[['W1',49.75,29.35],['W2',35.79,58.90],['W3',64.21,58.90]].map(([id,x,y])=>`<button class="hardpoint ${state.slot===id?'active':''}" data-slot="${id}" style="left:${x}%;top:${y}%" aria-label="选择${id}武器槽">${id}</button>`).join('')}</div>
    <div class="slot-rail"><div class="actions"><b>武器</b>${['W1','W2','W3'].map(id=>`<button class="${state.slot===id?'active':''}" data-slot="${id}">${id} ${slotData[id].type}</button>`).join('')}</div><div class="actions defence-rail"><b>防御</b>${['D1','D2'].map(id=>`<button class="${state.slot===id?'active':''}" data-slot="${id}">${id} ${slotData[id].type}</button>`).join('')}</div><p>当前舰的启用槽位</p><button class="compact" id="choose-hull">选择舰体</button></div>
    <section class="comparison"><h2>${state.slot} · ${slot.name}</h2><p class="identity">当前装配 ${currentType} · Lv.${currentLevel}</p>${success?completed:comparison}</section></div><p class="scene-note">固定样例：完成回执与可提交预览分开；成功后旧报价/按钮撤回。下一次操作必须重新读取目标、费用与合法性，本稿不生成下一笔报价。</p>`;
}
function completeEquipment(){
  const notice={};state.equipment='success';state.equipmentNotice=notice;render();
  setTimeout(()=>{if(state.equipment==='success'&&state.equipmentNotice===notice){state.equipmentNotice=false;if(active==='equipment')$('#equipment-feedback')?.remove();}},4500);
}
function transientResearchMessage(container,key,message){
  container[key]=message;
  setTimeout(()=>{if(container[key]===message){container[key]={type:'neutral',text:'已同步。'};if(active==='research'&&$('#investment-feedback-'+key))$('#investment-feedback-'+key).outerHTML=statusBlock('neutral','已同步。','investment-feedback-'+key);}},4500);
}
function render(){
  const m=modules.find(m=>m[0]===active);
  $('#title').textContent=m[1];$('#caption').textContent=m[2];
  $('#nav').innerHTML=modules.map(([id,name])=>`<button class="${active===id?'active':''}" data-module="${id}">${name}</button>`).join('');
  $('#scenario').innerHTML=(scenarios[active]||[['outline','仅主题说明']]).map(([id,name])=>`<option value="${id}" ${state[active]===id?'selected':''}>${name}</option>`).join('');
  $('#module-body').innerHTML=active==='reactor'?reactorView():active==='research'?researchView():active==='equipment'?equipmentView():`<div class="placeholder"><h2>${m[1]} · 尚无视觉细稿</h2><p>主题、对象与操作归属见design.md；此页只用于核对唯一导航，不冒充完成设计。</p></div>`;
  bind();
}
function selectModule(id){active=id;$('#app').classList.remove('collapsed');$('#collapse').textContent='收起舱室';render();history.replaceState(null,'',`?module=${id}`);}
function bind(){
  document.querySelectorAll('[data-module]').forEach(b=>b.onclick=()=>selectModule(b.dataset.module));
  document.querySelectorAll('[data-info]').forEach(b=>b.onclick=()=>openDialog('操作位置示意',`<p>${b.dataset.info}</p>`));
  document.querySelectorAll('[data-input]').forEach(i=>i.oninput=()=>{$(`#feedback-${i.dataset.input}`).textContent='编辑中，实际值保持；应用仅作用本设备。';});
  document.querySelectorAll('[data-apply]').forEach(b=>b.onclick=()=>{const id=b.dataset.apply;const value=$(`[data-input="${id}"]`).value;$(`#feedback-${id}`).classList.toggle('error',!/^\d+$/.test(value));$(`#feedback-${id}`).textContent=/^\d+$/.test(value)?'示例待业务校验；实际值未改变。':'请输入非负整数；草稿保留，实际值未改变。';});
  document.querySelectorAll('[data-clear]').forEach(b=>b.onclick=()=>{const id=b.dataset.clear;$(`#feedback-${id}`).textContent=`目标${id}：示例将调用allocate_text(id,"0")；本稿未提交，实际值保持。`;});
  document.querySelectorAll('[data-slot]').forEach(b=>b.onclick=()=>{state.slot=b.dataset.slot;state.equipment='compare';render();});
  $('#candidate')?.addEventListener('change',e=>{state.candidate=e.target.value;state.equipment='compare';render();});
  $('#equipment-commit')?.addEventListener('click',()=>{if(state.equipment==='insufficient'){$('#equipment-feedback').textContent='示例拒绝：缺少简并物质4。选择与候选保持。';return;}completeEquipment();});
  $('#choose-hull')?.addEventListener('click',()=>openDialog('舰体候选入口','<p>当前舰保持巡洋舰；候选应显示开放门槛、槽位启用变化和现有报价。确认前不改变当前舰。本轮尚无完整换舰细稿。</p>'));
  $('#investment-toggle')?.addEventListener('click',()=>{state.terminalMode=state.terminalMode==='manual'?null:'manual';render();});
  $('#automatic-toggle')?.addEventListener('click',()=>{state.terminalMode=state.terminalMode==='automatic'?null:'automatic';render();});
  for(const id of ['iron','uranium']){
    $('#'+id)?.addEventListener('input',e=>{state[id+'Draft']=e.target.value;state.investMessages[id]={type:'neutral',text:'草稿已编辑，尚未应用。'};$('#investment-feedback-'+id).outerHTML=statusBlock('neutral',state.investMessages[id].text,'investment-feedback-'+id);});
  }
  document.querySelectorAll('[data-invest-apply]').forEach(b=>b.onclick=()=>{
    const id=b.dataset.investApply,name=id==='iron'?'铁':'铀',text=state[id+'Draft'];
    if(!/^\d+$/.test(text)){state.investMessages[id]={type:'error',text:`${name}未应用：请输入非负整数；当前${state.manualActual[id]}保持。`};}
    else{state.manualActual[id]=text;transientResearchMessage(state.investMessages,id,{type:'success',text:`${name}已应用（示例），当前${text}/秒。`});}
    render();
  });
  document.querySelectorAll('[data-invest-reset]').forEach(b=>b.onclick=()=>{const id=b.dataset.investReset;state[id+'Draft']=state.manualActual[id];state.investMessages[id]={type:'neutral',text:'已还原至本资源当前值。'};render();});
  $('#auto-enabled')?.addEventListener('change',e=>{state.autoDraft.enabled=e.target.checked;state.autoMessage={type:'neutral',text:'开关草稿未应用。'};$('#automatic-feedback').outerHTML=statusBlock('neutral',state.autoMessage.text,'automatic-feedback');});
  $('#auto-ratio')?.addEventListener('input',e=>{state.autoDraft.ratio=e.target.value;state.autoMessage={type:'neutral',text:'比例草稿未应用；当前有效投入保持。'};$('#automatic-feedback').outerHTML=statusBlock('neutral',state.autoMessage.text,'automatic-feedback');});
  $('#apply-automatic')?.addEventListener('click',()=>{
    const raw=state.autoDraft.ratio;
    if(!/^\d+(\.\d+)?$/.test(raw)||Number(raw)>100){state.autoMessage={type:'error',text:'设置未应用：请使用模块允许的比例；草稿保留。'};}
    else{state.autoActual={...state.autoDraft};const message={type:'success',text:'自动设置已应用（示例）；当前有效投入未立即重算。'};state.autoMessage=message;setTimeout(()=>{if(state.autoMessage===message){state.autoMessage={type:'neutral',text:'设置已同步，等待实际预算刷新。'};if(active==='research'&&$('#automatic-feedback'))$('#automatic-feedback').outerHTML=statusBlock('neutral',state.autoMessage.text,'automatic-feedback');}},4500);}
    render();
  });
  $('#reset-automatic')?.addEventListener('click',()=>{state.autoDraft={...state.autoActual};state.autoMessage={type:'neutral',text:'已还原至当前自动设置。'};render();});
  $('#research-choose')?.addEventListener('click',()=>{state.research='choice';render();});
  document.querySelectorAll('[data-research]').forEach(b=>b.onclick=()=>{state.selectedResearch=b.dataset.research==='candidate';render();});
  $('#close-research')?.addEventListener('click',()=>{state.research='running';state.selectedResearch=false;render();});
  $('#confirm-research')?.addEventListener('click',()=>openDialog('切换研究的提交边界','<p>正式接入由现有Research.select处理，成功回执后才用新的active研究更新设备。此稿保留原舞台，不用候选预览假装已生效。</p>'));
}
$('#scenario').onchange=e=>{
  state[active]=e.target.value;
  if(active==='equipment'){
    state.candidate=e.target.value==='cooldown'?'replace':'upgrade';
    if(e.target.value==='success'){completeEquipment();return;}
  }
  if(active==='research'){
    paused=e.target.value==='paused';
    $('#pause').textContent=paused?'恢复':'暂停';$('#battle-state').textContent=paused?'已暂停 · 2 / 3 波':'交战中 · 2 / 3 波';
    if(e.target.value==='choice'){state.selectedResearch=true;state.terminalMode=null;}
    if(e.target.value==='automatic'){state.terminalMode='automatic';state.autoDraft={enabled:true,ratio:'30'};state.autoMessage={type:'neutral',text:'草稿开启 / 30%，尚未应用。'};}
    if(e.target.value==='partial'){
      state.terminalMode='manual';state.manualActual={iron:'120',uranium:'2'};state.ironDraft='120';state.uraniumDraft='abc';
      transientResearchMessage(state.investMessages,'iron',{type:'success',text:'铁已应用（示例），当前120/秒。'});
      state.investMessages.uranium={type:'error',text:'铀未应用：请输入非负整数；当前2保持。'};
    }
  }
  render();
};
$('#collapse').onclick=()=>{$('#app').classList.toggle('collapsed');};
$('#pause').onclick=()=>{paused=!paused;$('#pause').textContent=paused?'恢复':'暂停';$('#battle-state').textContent=paused?'已暂停 · 2 / 3 波':'交战中 · 2 / 3 波';if(active==='research')render();};
$('#guard').onclick=()=>{guarded=!guarded;$('#guard').textContent='驻守：'+(guarded?'开启':'关闭');};
$('#settings').onclick=()=>openDialog('系统设置位置','<p>音画、保存状态与目录、导入与新游戏。危险事务保留原预览/确认，不在本稿提交。</p>');
$('#archive').onclick=()=>openDialog('档案位置','<p>教程、敌方情报、通知。读取原模块公开事实，已见与已读分别呈现。</p>');
$('#battle-detail').onclick=()=>openDialog('战况示例','<p>盾甲当前/最大值、战斗统计、临时效果按需查看；本稿为固定样例，不证明实际native表现。</p>');
render();
