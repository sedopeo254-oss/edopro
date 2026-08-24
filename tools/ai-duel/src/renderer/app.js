'use strict';
const $=s=>document.querySelector(s),$$=s=>[...document.querySelectorAll(s)];
let state,activeSession=null,liveEvents=[],semanticFacts=[],mdScan=null;

const pageMeta={
  dashboard:['Dashboard','Build memory. Understand causes. Discover tactics.'],
  replays:['Replay Library','Structured evidence from every duel source.'],
  live:['Live Duel','Observe decisions and reconstruct what each action enabled.'],
  knowledge:['Knowledge Core','Understand card effects and unseen decks.'],
  masterduel:['Master Duel','Read-only Steam integration and source discovery/'],
  training:['AI Training','Search, self-play and the future EDOPro brain.'],
  settings:['Settings','Local-first configuration and data.']
};
function toast(message){const el=$('#toast');el.textContent=message;el.classList.add('show');clearTimeout(toast.t);toast.t=setTimeout(()=>el.classList.remove('show'),3200)}
function goto(page){$$('.nav-item').forEach(x=>x.classList.toggle('active',x.dataset.page===page));$$('.page').forEach(x=>x.classList.toggle('active',x.id===`page-${page}`));$('#pageTitle').textContent=pageMeta[page][0];$('#pageSubtitle').textContent=pageMeta[page][1]}
function num(n){return Number(n||0).toLocaleString()}function bytes(n){if(!n)return'0 B';if(n<1024)return`${n} B`;if(n<1048576)return`${(n/1024).toFixed(1)} KB`;if(n<1073741824)return`${(n/1048576).toFixed(1)} MB`;return`${(n/1073741824).toFixed(2)} GB`}
function shortDate(v){try{return new Date(v).toLocaleString()}catch{return v}}function esc(v){return String(v??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))}
function badge(el,ok,yes='READY',no='MISSING'){el.textContent=ok?yes:no;el.classList.toggle('amber',!ok);el.classList.toggle('green-pill',!!ok)}

async function refresh(){
  state=await window.aiDuel.getState();const c=state.counters;
  $('#statReplays').textContent=num(c.replays);$('#statEvents').textContent=num(c.events);$('#statFacts').textContent=num(c.semanticFacts);$('#statLinks').textContent=num(c.causalLinks);
  $('#knownCards').textContent=num(state.knowledge.cards.length);$('#knownRoles').textContent=num(state.knowledge.patterns.filter(p=>p.kind==='semantic-role').length);$('#cardRelations').textContent=num(state.knowledge.cardRelations?.length||0);
  renderReplays();renderRoles();renderSettings();renderMdFromState();
}
function renderReplays(){const root=$('#replayRows');if(!state.replays.length){root.innerHTML='<div class="empty">No replays imported yet.</div>';return}root.innerHTML=state.replays.map(r=>`<div class="row"><span><strong>${esc(r.originalName)}</strong><small>${esc(r.capture||r.id)}</small></span><span>${esc(r.sourceGame)}</span><span>${shortDate(r.importedAt)}</span><span>${bytes(r.size)}</span><span class="pill amber">${esc(r.status)}</span></div>`).join('')}
function renderRoles(){const roles=state.knowledge.patterns.filter(p=>p.kind==='semantic-role').slice(-80);$('#roleCloud').innerHTML=roles.length?roles.map(r=>`<span class="role">${esc(r.name)} <b>${r.evidence}</b></span>`).join(''):'<span class="empty">Import card data to build the semantic knowledge graph.</span>'}
function renderSettings(){
  $('#settingSource').value=state.settings.defaultSource;$('#settingMode').value=state.settings.observerMode;
  $('#settingMdPath').value=state.settings.masterDuelInstallPath||'';$('#mdPath').value=state.settings.masterDuelInstallPath||'';
}
function renderMdFromState(){const scan=state.masterDuel?.lastScan;if(scan){mdScan=scan;renderMd(scan)}else{$('#mdSideText').textContent='Master Duel: not scanned';$('#dashMdBadge').textContent='NOT SCANNED'}}

async function importReplay(){const source=state?.settings?.defaultSource||'Master Duel';try{const items=await window.aiDuel.importReplay(source);if(items.length){toast(`Imported ${items.length} replay file(s)`);await refresh();goto('replays')}}catch(e){toast(e.message)}}
async function importKnowledge(){try{const r=await window.aiDuel.importKnowledge();if(r){toast(`Added ${r.added} cards · ${r.relations} relations · semantic effects analyzed`);await refresh()}}catch(e){toast(`Knowledge import failed: ${e.message}`)}}

function renderLive(){
  $('#liveBadge').classList.toggle('on',!!activeSession);$('#liveBadge').classList.toggle('off',!activeSession);$('#liveBadge').innerHTML=`<span></span>${activeSession?'RECORDING':'OFFLINE'}`;
  $('#startLiveBtn').classList.toggle('hidden',!!activeSession);$('#stopLiveBtn').classList.toggle('hidden',!activeSession);$('#bridgeTest').classList.toggle('hidden',!activeSession);
  $('#sessionLabel').textContent=activeSession?activeSession.id:'No active session';$('#eventCount').textContent=`${liveEvents.length} EVENTS`;
  const root=$('#eventStream');root.innerHTML=liveEvents.length?liveEvents.slice().reverse().map(e=>{const r=e.raw||e;return`<div class="event-item"><span class="event-index">#${r.index}</span><span class="event-type">${esc(r.type)}</span><span class="event-note"><b>${esc(r.card?.name||r.card||'—')}</b> ${esc(r.summonMethod?`[${r.summonMethod}]`:r.note||'')}</span></div>`}).join(''):`<div class="empty">${activeSession?'Recording. Adapter events will appear here.':'Start a session to begin recording.'}</div>`;
  const facts=$('#semanticResult');facts.innerHTML=semanticFacts.length?semanticFacts.slice(-6).reverse().map(f=>`<div class="semantic-fact"><span>${Math.round((f.confidence||0)*100)}%</span><p>${esc(f.text)}</p></div>`).join(''):'<div class="empty">Semantic facts will appear here.</div>';
}
async function startLive(){
  try{
    const source=$('#liveSource').value;activeSession=await window.aiDuel.startLive({sourceGame:source,mode:$('#liveMode').value,installPath:$('#mdPath').value});liveEvents=[];semanticFacts=[];
    if(source==='Master Duel'){
      const m=activeSession.masterDuel,w=activeSession.watcher;$('#liveMdState').textContent=m?.valid?`Steam client detected · ${m.accounts.length} LocalData account(s) · replay watcher ${w?.enabled?'ON':'not available'}`:'Master Duel installation was not validated.';
    }
    renderLive();toast('Live Observer started');
  }catch(e){toast(e.message)}
}
async function stopLive(){try{await window.aiDuel.stopLive();activeSession=null;renderLive();await refresh();toast('Session and semantic knowledge saved')}catch(e){toast(e.message)}}
async function recordEvent(){
  const type=$('#eventType').value,card=$('#eventCard').value.trim(),method=$('#summonMethod').value,count=Number($('#eventCountInput').value)||undefined,note=$('#eventNote').value.trim();
  const event={type,player:0,card:card?{name:card}:null,summonMethod:method||undefined,count,note,reason:type==='TRIBUTE'?'TRIBUTE':undefined,source:'structured bridge test'};
  try{const out=await window.aiDuel.recordEvent(event);liveEvents.push(out);for(const f of out.semantic?.facts||[])semanticFacts.push(f);$('#eventCard').value='';$('#eventCountInput').value='';$('#eventNote').value='';renderLive();await refresh()}catch(e){toast(e.message)}
}

function pathLabel(p){if(!p)return'Not found';const s=String(p);return s.length>64?`…${s.slice(-61)}`:s}
function renderMd(scan){
  mdScan=scan;const ok=!!scan?.valid;$('#mdPageBadge').textContent=ok?'STEAM READY':'CHECK PATH';$('#mdPageBadge').classList.toggle('amber',!ok);$('#mdSideText').textContent=ok?`Master Duel: ${scan.accounts.length} account(s)`:'Master Duel: path not valid';$('#mdSideDot').classList.toggle('green',ok);$('#mdSideDot').classList.toggle('amber',!ok);
  $('#dashMdBadge').textContent=ok?'CONNECTED':'NOT READY';$('#dashMdBadge').classList.toggle('amber',!ok);$('#dashMdText').textContent=ok?`Found the Steam client, duel engine and ${scan.accounts.length} LocalData account(s). ${scan.ygoMaster?.replays?.exists?'A replay export folder is available for automatic capture.':'Exact live decision files are not exposed directly; semantic observer bridge remains the next decoder layer.'}`:'Scan your Master Duel Steam folder to discover available sources.';
  $('#mdPath').value=scan.root||$('#mdPath').value;$('#mdExe').textContent=pathLabel(scan.exe?.path);badge($('#mdExeBadge'),scan.exe?.exists);
  $('#mdDuelDll').textContent=pathLabel(scan.duelEngine?.path);badge($('#mdDuelBadge'),scan.duelEngine?.exists);
  $('#mdLocal').textContent=scan.localData?.exists?`${scan.accounts.length} account folder(s)`:'LocalData not found';badge($('#mdLocalBadge'),scan.localData?.exists);
  const assetReady=scan.streamingAssets?.exists||scan.accounts?.length;$('#mdAssets').textContent=scan.accountStats?`${num(scan.accountStats.reduce((n,a)=>n+a.files,0))} LocalData files · ${bytes(scan.accountStats.reduce((n,a)=>n+a.bytes,0))}`:'Asset stores discovered';badge($('#mdAssetsBadge'),assetReady);
  const replayReady=scan.ygoMaster?.replays?.exists;$('#mdReplayBridge').textContent=replayReady?pathLabel(scan.ygoMaster.replays.path):'No exported replay folder detected';badge($('#mdReplayBadge'),replayReady,'AVAILABLE','NEEDS BRIDGE');
  $('#mdAccountCount').textContent=scan.accounts?.length||0;const root=$('#mdAccounts');root.innerHTML=scan.accounts?.length?scan.accounts.map((a,i)=>{const st=scan.accountStats?.find(x=>x.name===a.name);const hints=Object.values(a.cardBundleHints||{}).filter(x=>x.exists).length;return`<div class="account-item"><div><b>${esc(a.name)}</b><small>${st?`${num(st.files)} files · ${bytes(st.bytes)}`:'LocalData account'} · ${hints}/5 card text/index bundle hints located</small></div><span class="pill">ACCOUNT ${i+1}</span></div>`}).join(''):'<div class="empty">No LocalData accounts detected.</div>';
}
async function scanMd(){
  const btn=$('#mdScanBtn');try{btn.disabled=true;btn.textContent='Scanning…';const scan=await window.aiDuel.scanMasterDuel($('#mdPath').value);renderMd(scan);await refresh();toast(scan.valid?`Master Duel detected · ${scan.accounts.length} account(s)`:'Could not validate Master Duel at this path')}catch(e){toast(`Scan failed: ${e.message}`)}finally{btn.disabled=false;btn.textContent='Scan'}}
async function browseMd(){try{const scan=await window.aiDuel.chooseMasterDuelFolder();if(scan){renderMd(scan);$('#settingMdPath').value=scan.root;await window.aiDuel.updateSettings({masterDuelInstallPath:scan.root});toast('Master Duel folder selected')}}catch(e){toast(e.message)}}
async function runSemanticDemo(){
  try{const d=await window.aiDuel.runSemanticDemo(),facts=d.snapshot.facts||[],links=d.snapshot.links||[];$('#semanticDemoOutput').innerHTML=facts.map(f=>`<div class="demo-line"><span class="demo-kind">${esc(f.kind)}</span><p>${esc(f.text)}</p><b>${Math.round((f.confidence||0)*100)}%</b></div>`).join('')+`<div class="demo-summary">${facts.length} facts · ${links.length} causal links</div>`;toast('Semantic causality test complete')}catch(e){toast(e.message)}}

async function init(){
  $$('.nav-item').forEach(x=>x.addEventListener('click',()=>goto(x.dataset.page)));$$('[data-goto]').forEach(x=>x.addEventListener('click',()=>goto(x.dataset.goto)));
  $('#quickImportBtn').onclick=importReplay;$('#importReplayBtn').onclick=importReplay;$('#importKnowledgeBtn').onclick=importKnowledge;$('#semanticDemoBtn').onclick=runSemanticDemo;
  $('#startLiveBtn').onclick=startLive;$('#stopLiveBtn').onclick=stopLive;$('#recordEventBtn').onclick=recordEvent;
  $('#mdBrowseBtn').onclick=browseMd;$('#mdScanBtn').onclick=scanMd;$('#mdOpenBtn').onclick=()=>window.aiDuel.openMasterDuelFolder();
  $('#openDataBtn').onclick=()=>window.aiDuel.openDataFolder();$('#settingsOpenData').onclick=()=>window.aiDuel.openDataFolder();
  $('#settingSource').onchange=async e=>{await window.aiDuel.updateSettings({defaultSource:e.target.value});await refresh();toast('Default source saved')};
  $('#settingMode').onchange=async e=>{await window.aiDuel.updateSettings({observerMode:e.target.value});await refresh();toast('Learning mode saved')};
  $('#settingMdSave').onclick=async()=>{const p=$('#settingMdPath').value.trim();await window.aiDuel.updateSettings({masterDuelInstallPath:p});$('#mdPath').value=p;await refresh();toast('Master Duel path saved')};
  window.aiDuel.onReplayCaptured(async item=>{toast(`New Master Duel replay captured: ${item.originalName}`);await refresh()});
  const info=await window.aiDuel.appInfo();$('#version').textContent=`v${info.version}`;$('#dataPath').textContent=info.userData;
  await refresh();renderLive();
  // Fast non-recursive validation on startup; deep scan remains user-triggered.
  try{const scan=await window.aiDuel.inspectMasterDuel(state.settings.masterDuelInstallPath);if(scan?.valid)renderMd(scan)}catch{}
}
init();
