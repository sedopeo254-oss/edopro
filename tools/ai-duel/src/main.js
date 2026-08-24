'use strict';
const{app,BrowserWindow,ipcMain,dialog,shell}=require('electron');
const path=require('path');
const fs=require('fs');
const{Storage}=require('./core/storage');
const{analyzeCards,inferCardRelations}=require('./core/knowledge');
const{SemanticDuelEngine}=require('./core/semantic-engine');
const{MasterDuelAdapter}=require('./adapters/master-duel-adapter');
const{BridgeReceiver}=require('./core/bridge-receiver');

let win,storage,activeSessionId=null,semanticEngine=null,replayWatchTimer=null,replayWatchSeen=new Map(),bridge=null,bridgeAutoSession=false;
const masterDuel=new MasterDuelAdapter();

function currentCards(){return storage?.read().knowledge.cards||[]}
function safeSend(channel,payload){try{if(win&&!win.isDestroyed())win.webContents.send(channel,payload)}catch{}}

function startBridge(){
  if(bridge)return bridge.status();
  bridge=new BridgeReceiver(app.getPath('userData'),17384);
  bridge.on('status',st=>safeSend('bridge:status',st));
  bridge.on('event',ev=>{
    safeSend('bridge:event',ev);
    try{
      if(!activeSessionId){
        const s=storage.startSession('Master Duel','Bridge Auto',{captureMode:'Master Duel engine bridge',bridgePort:17384});
        activeSessionId=s.id;bridgeAutoSession=true;semanticEngine=new SemanticDuelEngine(currentCards());
        safeSend('bridge:auto-session',{started:true,session:s});
      }
      const raw=storage.appendEvent(activeSessionId,{...ev,type:ev.action||ev.type||'BRIDGE_EVENT',source:'Master Duel Bridge'});
      const result=semanticEngine.ingest(raw);storage.recordSemanticOutput(activeSessionId,result);
      safeSend('bridge:semantic',{raw,semantic:result});
    }catch(e){safeSend('bridge:error',{message:e.message})}
  });
  bridge.on('message',m=>{
    safeSend('bridge:message',m);
    const t=String(m?.type||'').toUpperCase();
    try{
      if(t==='DUEL_BEGIN'){
        if(activeSessionId&&bridgeAutoSession){try{storage.stopSession(activeSessionId)}catch{}activeSessionId=null;semanticEngine=null}
        if(!activeSessionId){
          const s=storage.startSession('Master Duel','Bridge Auto',{captureMode:'Master Duel engine bridge',bridgeSession:m.session||null,bridgePort:17384});
          activeSessionId=s.id;bridgeAutoSession=true;semanticEngine=new SemanticDuelEngine(currentCards());
          safeSend('bridge:auto-session',{started:true,session:s,bridgeMessage:m});
        }
      }else if(t==='DUEL_END'&&activeSessionId&&bridgeAutoSession){
        const x=storage.stopSession(activeSessionId);activeSessionId=null;bridgeAutoSession=false;semanticEngine=null;
        safeSend('bridge:auto-session',{started:false,session:x,bridgeMessage:m});
      }
    }catch(e){safeSend('bridge:error',{message:e.message})}
  });
  bridge.start().then(st=>safeSend('bridge:status',st)).catch(e=>safeSend('bridge:error',{message:e.message}));
  return bridge.status();
}
function stopBridge(){try{bridge?.stop()}catch{}bridge=null}

function createWindow(){
  storage=new Storage(app.getPath('userData'));
  win=new BrowserWindow({width:1440,height:900,minWidth:1120,minHeight:720,backgroundColor:'#070b12',title:'Ai Duel',autoHideMenuBar:true,webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true,nodeIntegration:false,sandbox:false}});
  win.loadFile(path.join(__dirname,'renderer','index.html'));
  startBridge();
}
app.whenReady().then(()=>{createWindow();app.on('activate',()=>{if(BrowserWindow.getAllWindows().length===0)createWindow()})});
app.on('window-all-closed',()=>{stopReplayWatcher();stopBridge();if(process.platform!=='darwin')app.quit()});

function stopReplayWatcher(){if(replayWatchTimer){clearInterval(replayWatchTimer);replayWatchTimer=null}replayWatchSeen.clear();if(storage)storage.updateWatch({enabled:false})}
function startReplayWatcher(scan){
  stopReplayWatcher();
  const dir=scan?.ygoMaster?.replays?.path;
  if(!dir||!fs.existsSync(dir))return{enabled:false,reason:'No exported replay folder detected'};
  const prime=()=>{for(const f of masterDuel.listReplayFiles(scan))replayWatchSeen.set(f.path,`${f.size}|${f.mtime}`)};
  prime();
  replayWatchTimer=setInterval(()=>{
    try{
      const files=masterDuel.listReplayFiles(scan);
      for(const f of files){
        const sig=`${f.size}|${f.mtime}`,old=replayWatchSeen.get(f.path);
        if(!old){
          replayWatchSeen.set(f.path,sig);
          const item=storage.importReplay(f.path,'Master Duel',{capture:'Steam/YgoMaster replay watcher'});
          safeSend('md:replay-captured',item);
        }else if(old!==sig) replayWatchSeen.set(f.path,sig);
      }
    }catch{}
  },2500);
  storage.updateWatch({enabled:true,replayDir:dir,startedAt:new Date().toISOString()});
  return{enabled:true,replayDir:dir};
}

ipcMain.handle('state:get',()=>storage.read());
ipcMain.handle('replay:import',async(_e,sourceGame)=>{
  const r=await dialog.showOpenDialog(win,{title:'Import Duel Replay / Duel Data',properties:['openFile','multiSelections'],filters:[{name:'Duel data',extensions:['json','jsonl','txt','log','yrp','yrpx','replay']},{name:'All files',extensions:['*']}]});
  if(r.canceled)return[];return r.filePaths.map(f=>storage.importReplay(f,sourceGame||'Master Duel'));
});
ipcMain.handle('knowledge:import',async()=>{
  const r=await dialog.showOpenDialog(win,{title:'Import Card Knowledge JSON',properties:['openFile'],filters:[{name:'JSON',extensions:['json']}]});
  if(r.canceled||!r.filePaths[0])return null;
  const x=storage.importKnowledge(r.filePaths[0]),s=storage.read(),a=analyzeCards(s.knowledge.cards),relations=inferCardRelations(a.analyzed);
  storage.mutate(st=>{
    st.knowledge.cards=a.analyzed;st.knowledge.cardRelations=relations;
    const all={...a.roleCounts,...Object.fromEntries(Object.entries(a.operationCounts).map(([k,v])=>[`operation:${k}`,v])),...Object.fromEntries(Object.entries(a.triggerCounts).map(([k,v])=>[`trigger:${k}`,v]))};
    for(const[name,count]of Object.entries(all)){
      const id=`semantic:${name}`,p={id,kind:'semantic-role',name,evidence:count,updatedAt:new Date().toISOString()},i=st.knowledge.patterns.findIndex(v=>v.id===id);if(i>=0)st.knowledge.patterns[i]=p;else st.knowledge.patterns.push(p;
    }
  });
  return{...x,roleCounts:a.roleCounts,operationCounts:a.operationCounts,triggerCounts:a.triggerCounts,relations:relations.length};
});

ipcMain.handle('md:choose-folder',async()=>{
  const state=storage.read();
  const r=await dialog.showOpenDialog(win,{title:'Select Yu-Gi-Oh! Master Duel Steam Folder',defaultPath:state.settings.masterDuelInstallPath||masterDuel.defaultInstallPath(),properties:['openDirectory']});
  if(r.canceled||!r.filePaths[0])return null;storage.updateSettings({masterDuelInstallPath:r.filePaths[0]});return masterDuel.inspectInstall(r.filePaths[0]);
});
ipcMain.handle('md:inspect',(_e,root)=>masterDuel.inspectInstall(root||storage.read().settings.masterDuelInstallPath));
ipcMain.handle('md:scan',async(_e,root)=>{const scan=await masterDuel.deepScan(root||storage.read().settings.masterDuelInstallPath);storage.updateMasterDuelScan(scan);return scan});
ipcMain.handle('md:open-game-folder',()=>shell.openPath(storage.read().settings.masterDuelInstallPath||masterDuel.defaultInstallPath()));

ipcMain.handle('bridge:status',()=>bridge?bridge.status():{running:false,connected:false,port:17384});
ipcMain.handle('bridge:start',()=>startBridge());
ipcMain.handle('bridge:open-output',()=>shell.openPath(bridge?bridge.writer.dir:path.join(app.getPath('userData'),'data','windbot')));

ipcMain.handle('live:start',(_e,p)=>{
  if(activeSessionId)throw new Error('Observer is already running');
  const source=p?.sourceGame||'Master Duel',mode=p?.mode||'Observer',installPath=p?.installPath||storage.read().settings.masterDuelInstallPath;
  const scan=source==='Master Duel'?masterDuel.inspectInstall(installPath):null;
  const s=storage.startSession(source,mode,{installPath:scan?.root||null,captureMode:scan?'read-only Steam sources + semantic reconstruction':'generic semantic bridge'});
  activeSessionId=s.id;bridgeAutoSession=false;semanticEngine=new SemanticDuelEngine(currentCards());
  const watcher=scan?startReplayWatcher(scan):{enabled:false};
  return{...s,masterDuel:scan,watcher,bridge:bridge?.status()};
});
ipcMain.handle('live:event',(_e,event)=>{
  if(!activeSessionId)throw new Error('Start Live Observer first');
  const raw=storage.appendEvent(activeSessionId,event||{});
  const result=semanticEngine.ingest(raw);storage.recordSemanticOutput(activeSessionId,result);
  return{raw,semantic:result};
});
ipcMain.handle('live:stop',()=>{if(!activeSessionId)return null;stopReplayWatcher();const x=storage.stopSession(activeSessionId);activeSessionId=null;bridgeAutoSession=false;semanticEngine=null;return x});

ipcMain.handle('semantic:demo',()=>{
  const cards=[{id:900001,name:'Ai Duel Tribute Scholar',level:7,text:'If this card is Tribute Summoned: Draw 2 cards.'},{id:900002,name:'Material Alpha',level:4,text:''},{id:900003,name:'Material Beta',level:4,text:''}];
  const eng=new SemanticDuelEngine(cards);
  const events=[{id:'demo1',type:'TRIBUTE',player:0,card:cards[1],reason:'TRIBUTE',from:'MONSTER_ZONE',to:'GY'},{id:'demo2',type:'TRIBUTE',player:0,card:cards[2],reason:'TRIBUTE',from:'MONSTER_ZONE',to:'GY'},{id:'demo3',type:'SUMMON',player:0,card:cards[0]},{id:'demo4',type:'EFFECT_ACTIVATE',player:0,card:cards[0],effectIndex:0},{id:'demo5',type:'DRAW',player:0,count:2}];
  const outputs=eng.ingestMany(events);return{outputs,snapshot:eng.snapshot()};
});

ipcMain.handle('settings:update',(_e,p)=>storage.updateSettings(p||{}));
ipcMain.handle('data:open-folder',()=>shell.openPath(path.join(app.getPath('userData'),'data')));
ipcMain.handle('app:info',()=>({version:app.getVersion(),userData:app.getPath('userData'),defaultMasterDuelPath:masterDuel.defaultInstallPath(),bridgePort:17384}));
