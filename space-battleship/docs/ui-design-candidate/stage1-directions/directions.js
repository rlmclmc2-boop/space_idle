// Stage-one direction comparison, fixed presentation fixtures only. No game/API connection.
const el=s=>document.querySelector(s);
const params=new URLSearchParams(location.search);
const definitions={a:{name:'全景＋侧浮坞'},b:{name:'底部工作台'},c:{name:'舱室模式＋战况仪'},d:{name:'常驻双焦工作场'}};
const equipment={
 W1:{type:'舰炮',description:'单发重击',rows:[['19','12.6K','2.4K'],['20','14.2K','2.9K'],['21','16.0K','3.5K'],['22','18.1K',null]]},
 W2:{type:'脉冲',description:'能量武器',rows:[['18','8.4K','1.8K'],['19','9.5K','2.1K'],['20','10.6K',null]]},
 W3:{type:'舰炮',description:'单发重击',rows:[['17','9.8K','1.4K'],['18','11.1K','1.7K'],['19','12.6K',null]]}
};
const candidates=[{key:'舰炮',summary:'单发重击',tradeoff:'即时单击，集中打击当前目标。',image:'cannon.png'},{key:'导弹',summary:'分散目标',tradeoff:'飞行后接触命中，适合分散攻击目标。',image:'missile.png'},{key:'长激光',summary:'持续蓄力',tradeoff:'持续光束按有效伤害跳结算。',image:'longLaser.png'}];
const initial=()=>({module:null,slot:'W1',indices:{W1:0,W2:0,W3:0},types:{W1:'舰炮',W2:'脉冲',W3:'舰炮'},candidates:{W1:null,W2:null,W3:null},locks:{},paused:false,failure:false,intent:null,feedback:'',feedbackKind:'neutral',log:[],counts:{open:0,close:0,slot:0,candidate:0,upgrade:0,refit:0,deep:0}});
let model=initial();
let direction=definitions[params.get('direction')]?params.get('direction'):'a';
const screen=el('#screen');
if(params.get('capture')==='1')document.body.classList.add('capture');
function record(type,detail){model.log.push({type,detail});if(type in model.counts)model.counts[type]++;}
function quote(){const row=equipment[model.slot].rows[model.indices[model.slot]],next=equipment[model.slot].rows[model.indices[model.slot]+1];return {level:row[0],value:row[1],price:row[2],target:next?.[0]};}
function speak(text,kind='neutral'){model.feedback=text;model.feedbackKind=kind;renderWork();}
function openModule(name){if(model.module===name){closeModule();return;}model.module=name;record('open',name);render();}
function closeModule(){record('close',model.module);model.module=null;render();}
function fleet(){
 const q=quote(),slot=model.slot,current=model.types[slot],candidate=model.candidates[slot],choice=candidates.find(c=>c.key===candidate),locked=model.locks[slot];
 return `<div class="fleet"><div class="ship-context"><img src="../../../assets/ui/ships/fleet_20261019/03-cruiser.png" alt="当前舰预览参考"></div><div class="object-heading"><div><h2>巡洋舰整备</h2><p>当前舰 · 三个武器槽</p></div><button class="close-work" data-close>收起</button></div>
  <div class="slot-strip">${Object.keys(equipment).map(id=>`<button data-slot="${id}" class="${id===slot?'selected':''}"><b>${id} · ${model.types[id]}</b>Lv.${equipment[id].rows[model.indices[id]][0]}${model.locks[id]?' · 换装锁':''}</button>`).join('')}</div>
  <div class="current-summary"><h3>${slot} · ${current} Lv.${q.level}</h3><p>${current==='长激光'?'持续伤害（按秒）':current==='导弹'?'飞行接触命中':'单次攻击'} · 样例属性 ${q.value}</p></div>
  <div class="upgrade-area"><div><h4>下一次购级</h4><p>${q.target?`Lv.${q.level} → ${q.target} · 铁${q.price}`:'报价准备中'}</p></div><button class="primary" data-upgrade ${!q.price?'disabled':''}>购买1级</button></div>
  <section class="candidate-catalog"><h4>直接选择换装候选</h4><div class="candidate-options">${candidates.map(c=>`<button data-candidate="${c.key}" class="${candidate===c.key?'selected':''} ${current===c.key?'equipped':''}"><img alt="" src="../../../assets/weapons/fleet_20261019/${c.image}"><b>${c.key}</b><span>${current===c.key?'当前装备':c.summary}</span></button>`).join('')}</div></section>
  <div class="selection-decision"><p>${locked?'换装锁剩余10游戏秒；购级与其他槽仍可操作。':choice&&candidate!==current?`候选${candidate}：${choice.tradeoff} 保留槽位等级${q.level}。`:'换装保留槽位等级。'}</p><button data-refit ${!choice||candidate===current||locked?'disabled':''}>${locked?'换装冷却中':'确认换装'}</button></div>
  <details class="deep" id="deep"><summary>深入属性与限制</summary><p>当前 ${slot} · ${current} Lv.${q.level}。换装锁与武器攻击周期是两种状态。</p><dl><div><dt>伤害类型</dt><dd>${current==='舰炮'||current==='导弹'?'物理':'能量'}</dd></div><div><dt>命中方式</dt><dd>${current==='导弹'?'飞行接触':current==='长激光'?'持续伤害跳':'即时命中'}</dd></div><div><dt>当前主属性</dt><dd>${q.value}${current==='长激光'?'/秒':'/发'}</dd></div><div><dt>攻击周期</dt><dd>1.2秒（样例）</dd></div><div><dt>换装锁</dt><dd>${locked?'剩余10游戏秒':'可更换'}</dd></div></dl><p>购级不触发换装锁。</p></details>
  <div class="feedback ${model.feedbackKind}" role="status">${model.feedback?`${model.feedbackKind==='error'?'!':'✓'} ${model.feedback}`:''}</div>
 </div>`;
}
function reactor(){return `<div class="reactor-layout"><div class="object-heading"><div><h2>动力舱 / 配电</h2><p>粗构图 · 意图入口尚未定稿</p></div><button class="close-work" data-close>收起</button></div>
 <div class="reactor-structure"><svg viewBox="0 0 440 220" aria-label="设备安装空间粗示意"><defs><linearGradient id="metal" x2="0" y2="1"><stop stop-color="#9ab8ae"/><stop offset="1" stop-color="#355660"/></linearGradient></defs><path d="M20 192L93 157H335L420 192Z" fill="#163541" stroke="#739b94"/><path d="M65 165V28H344V165M86 32V161M325 32V161" fill="none" stroke="#70988d" stroke-width="8"/><path d="M105 170V70L142 46H248L286 70V170Z" fill="url(#metal)" stroke="#d5dec9" stroke-width="3"/><ellipse cx="195" cy="107" rx="53" ry="66" fill="#203e4d" stroke="#b3d8c4" stroke-width="8"/><ellipse cx="195" cy="107" rx="36" ry="49" fill="#679e98"/><path d="M96 105H53M293 105H350V148H386" fill="none" stroke="#92baaa" stroke-width="9"/><path d="M65 176H331" stroke="#9bb8a3" stroke-width="8"/></svg></div>
 <div class="intent-board"><div class="intent-current">手动池 <strong>3.20e24</strong><br>当前剩余 0.48e24</div><div class="intent-bars">${[['武器',50,'1.60e24'],['防御',25,'0.80e24'],['炼铁',10,'0.32e24']].map(([name,n,value])=>`<div class="intent-row"><span>${name}</span><div class="intent-bar"><i style="width:${n}%"></i></div><span>${value}</span></div>`).join('')}</div></div>
 <div class="intent-controls"><h4>表达分配意图 · 概念入口</h4><div class="intent-buttons"><button data-intent="偏向武器">偏向武器</button><button data-intent="偏向防御">偏向防御</button><button data-intent="多留余量">多留余量</button><button data-intent="均分">均分</button></div><div class="intent-preview">${model.intent?`意图预览：${model.intent}。当前实际分配未改变。`:'当前分配：武器为主，仍有余量。'}</div><p class="coarse-note">阶段1仅比较空间与入口。意图→Amount请求、即时/确认形式与粒度待原契约线程核对，未新增挪用其他设备或原子事务。</p></div>
 </div>`;}
function scenic(){const planet=model.module==='planet';return `<div class="object-heading"><h2>${planet?'始源星 / 轨道探索':'武器精准 / 研究中'}</h2><button class="close-work" data-close>收起</button></div><div class="scenic ${planet?'scenic-planet':''}">${planet?'':`<img class="scenic-bg" alt="现有工厂空间参考" src="../../../assets/ai_tech_factory/workshop-background-v2.png">`}<img class="scenic-object" alt="既有资源粗参照" src="../../../assets/${planet?'ui/planet-globe.png':'ai_tech_factory/weapon-accuracy-v2.png'}"><div class="scenic-caption"><h3>${planet?'探索队正在工作':'当前设备与平台'}</h3><p>${planet?'设施详情应跟随轨道对象，不强套配电面板':'观察信息应聚在设备工作点，终端按需展开'}</p></div></div><p class="coarse-note">仅用来观察本方向能否容纳场景型模块，不是阶段3细稿或资产映射批准。</p>`;}
function renderWork(){
 const work=el('#workplace');work.hidden=!model.module;work.classList.toggle('scenic-work',['planet','research'].includes(model.module));
 if(!model.module)return;
 work.innerHTML=model.module==='fleet'?fleet():model.module==='reactor'?reactor():scenic();
 work.querySelector('[data-close]').onclick=closeModule;
 work.querySelectorAll('[data-slot]').forEach(b=>b.onclick=()=>{model.slot=b.dataset.slot;model.feedback='';record('slot',model.slot);renderWork();});
 work.querySelectorAll('[data-candidate]').forEach(b=>b.onclick=()=>{model.candidates[model.slot]=b.dataset.candidate;record('candidate',{slot:model.slot,type:b.dataset.candidate});model.feedback='';renderWork();});
 work.querySelector('[data-upgrade]')?.addEventListener('click',()=>{if(model.failure){speak('铁余额不足，本槽选择保持；可继续查看其他槽。','error');record('reject',model.slot);return;}if(quote().price){const before=quote().level;model.indices[model.slot]++;record('upgrade',model.slot);speak(`${model.slot} ${before}→${quote().level}，下一笔报价已就绪。`);}});
 work.querySelector('[data-refit]')?.addEventListener('click',()=>{const target=model.candidates[model.slot];if(target&&target!==model.types[model.slot]&&!model.locks[model.slot]){model.types[model.slot]=target;model.locks[model.slot]=true;record('refit',{slot:model.slot,type:target});speak(`${model.slot}已换为${target}，等级${quote().level}保留；仍可选择其他槽。`);}});
 work.querySelectorAll('[data-intent]').forEach(b=>b.onclick=()=>{model.intent=b.dataset.intent;record('intent',model.intent);renderWork();});
 work.querySelector('#deep')?.addEventListener('toggle',e=>{if(e.target.open)record('deep',model.slot);});
}
function render(){
 screen.className=`screen layout-${direction}${model.module?' open module-'+model.module:''}`;el('#observe').hidden=!(direction==='c'&&model.module);el('#pause').textContent=model.paused?'恢复':'暂停';el('#combat-state').textContent=model.paused?'已暂停 · 2/3波':'交战中 · 2/3波';
 el('.wallet span:first-child b').textContent=model.failure?'0':'2.48M';
 document.querySelectorAll('[data-module]').forEach(b=>b.classList.toggle('active',b.dataset.module===model.module));
 el('#direction-picker').value=direction;renderWork();
 history.replaceState(null,'',`?direction=${direction}${model.module?'&state='+model.module:''}${params.get('capture')==='1'?'&capture=1':''}`);
}
function preset(name){model=initial();if(name==='reactor')model.module='reactor';if(['fleet','sequence','failure'].includes(name))model.module='fleet';if(name==='sequence'){model.indices={W1:2,W2:0,W3:1};model.types.W2='导弹';model.candidates.W2='导弹';model.locks.W2=true;model.slot='W1';model.feedback='连续路径结束：W1 Lv.21，工作台仍在，下一笔Lv.22报价就绪。';}if(name==='failure'){model.slot='W3';model.failure=true;model.feedback='铁余额不足，本槽选择保持；可继续查看其他槽。';model.feedbackKind='error';}render();}
function switchDirection(id){direction=id;render();}
document.querySelectorAll('[data-module]').forEach(b=>b.onclick=()=>openModule(b.dataset.module));
el('#pause').onclick=()=>{model.paused=!model.paused;record('pause',model.paused);render();};el('#observe').onclick=closeModule;
el('#more-nav').onclick=()=>{el('#notice').hidden=false;el('#notice').textContent='阶段1的其他舱室只在模板说明粗构图，不把未展开导航当作游戏未解锁。';setTimeout(()=>el('#notice').hidden=true,4000);};
el('#review-toggle').onclick=()=>el('#review-tools').hidden=!el('#review-tools').hidden;
el('#direction-picker').onchange=e=>switchDirection(e.target.value);
document.querySelectorAll('[data-preset]').forEach(b=>b.onclick=()=>preset(b.dataset.preset));el('#reset').onclick=()=>preset('idle');
let resizeStart=null;el('#divider').onpointerdown=e=>{if(direction!=='d'||!model.module)return;resizeStart=true;el('#divider').setPointerCapture(e.pointerId);};el('#divider').onpointermove=e=>{if(resizeStart){const value=Math.max(44,Math.min(65,e.clientX/innerWidth*100));screen.style.setProperty('--split',value+'%');}};el('#divider').onpointerup=()=>resizeStart=null;el('#divider').onkeydown=e=>{if(e.key==='ArrowLeft'||e.key==='ArrowRight'){const current=parseFloat(screen.style.getPropertyValue('--split'))||56;screen.style.setProperty('--split',Math.max(44,Math.min(65,current+(e.key==='ArrowRight'?1:-1)))+'%');}};
window.directionReview={preset,switchDirection,getState:()=>JSON.parse(JSON.stringify(model)),getGeometry:()=>({direction,field:el('.field').getBoundingClientRect().toJSON(),arena:el('.arena').getBoundingClientRect().toJSON(),work:el('#workplace').hidden?null:el('#workplace').getBoundingClientRect().toJSON()})};
preset(params.get('state')||'idle');
