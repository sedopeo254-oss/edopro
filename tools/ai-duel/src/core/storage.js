'use strict';
const fs=require('fs');
const path=require('path');

const EMPTY_STATE={
  version:2,createdAt:null,
  counters:{replays:0,liveSessions:0,events:0,decks:0,tacticalPatterns:0,comebackPatterns:0,semanticFacts:0,causalLinks:0,steamScans:0},
  replays:[],liveSessions:[],
  knowledge:{cards:[],decks:[],patterns:[],semanticFacts:[],causalLinks:[],cardRelations:[]},
  masterDuel:{installPath:'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Yu-Gi-Oh! Master Duel',lastScan:null,watch:{enabled:false,lastSeenReplayMtimes:{}}},
  settings:{defaultSource:'Master Duel',observerMode:'Observer',autoAnalyzeImports:true,safeReadOnlyCapture:true,masterDuelInstallPath:'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Yu-Gi-Oh! Master Duel'}
};

function clone(v){return JSON.parse(JSON.stringify(v))}
class Storage{
  constructor(root){this.root=root;this.dataDir=path.join(root,'data');this.replaysDir=path.join(this.dataDir,'replays');this.sessionsDir=path.join(this.dataDir,'sessions');this.stateFile=path.join(this.dataDir,'state.json');this.ensure()}
  ensure(){fs.mkdirSync(this.replaysDir,{recursive:true});fs.mkdirSync(this.sessionsDir,{recursive:true});if(!fs.existsSync(this.stateFile)){const s=clone(EMPTY_STATE);s.createdAt=new Date().toISOString();this.write(s)}}
  normalize(s){
    const b=clone(EMPTY_STATE),k=s?.knowledge||{},md=s?.masterDuel||{};
    return{...b,...s,version:2,
      counters:{...b.counters,...(s?.counters||{})},
      knowledge:{...b.knowledge,...k,cards:Array.isArray(k.cards)?k.cards:[],decks:Array.isArray(k.decks)?k.decks:[],patterns:Array.isArray(k.patterns)?k.patterns:[],semanticFacts:Array.isArray(k.semanticFacts)?k.semanticFacts:[],causalLinks:Array.isArray(k.causalLinks)?k.causalLinks:[],cardRelations:Array.isArray(k.cardRelations)?k.cardRelations:[]},
      masterDuel:{...b.masterDuel,...md,watch:{...b.masterDuel.watch,...(md.watch||{})}},
      settings:{...b.settings,...(s?.settings||{})},
      replays:Array.isArray(s?.replays)?s.replays:[],liveSessions:Array.isArray(s?.liveSessions)?s.liveSessions:[]};
  }
  read(){try{return this.normalize(JSON.parse(fs.readFileSync(this.stateFile,'utf8')))}catch{const s=clone(EMPTY_STATE);s.createdAt=new Date().toISOString();this.write(s);return s}}
  write(s){fs.writeFileSync(this.stateFile,JSON.stringify(s,null,2),'utf8')}
  recount(s){
    s.counters.replays=s.replays.length;s.counters.liveSessions=s.liveSessions.length;
    s.counters.events=s.liveSessions.reduce((n,x)=>n+(x.eventCount||0),0);
    s.counters.decks=s.knowledge.decks.length;s.counters.tacticalPatterns=s.knowledge.patterns.length;
    s.counters.comebackPatterns=s.knowledge.patterns.filter(p=>p.kind==='comeback').length;
    s.counters.semanticFacts=s.knowledge.semanticFacts.length;s.counters.causalLinks=s.knowledge.causalLinks.length;
    s.counters.steamScans=s.masterDuel.lastScan?1:0;
  }
  mutate(fn){const s=this.read();fn(s);this.recount(s);this.write(s);return s}
  safeName(n){return n.replace(/[<>:\"/\\|?*\x00-\x1F]/g,'_').slice(0,180)}
  importReplay(sourcePath,sourceGame='Master Duel',meta={}){
    const st=fs.statSync(sourcePath),name=path.basename(sourcePath),signature=`${path.resolve(sourcePath)}|${st.size}|${st.mtimeMs}`;
    const existing=this.read().replays.find(r=>r.sourceSignature===signature);if(existing)return existing;
    const stamp=Date.now(),stored=`${stamp}_${this.safeName(name)}`;fs.copyFileSync(sourcePath,path.join(this.replaysDir,stored));
    const r={id:`replay_${stamp}_${Math.random().toString(16).slice(2,8)}`,sourceGame,originalName:name,sourcePath:path.resolve(sourcePath),sourceSignature:signature,storedName:stored,importedAt:new Date().toISOString(),size:st.size,status:'Captured — semantic decode pending',analysis:{events:0,turns:null,decks:[],patterns:[],semanticFacts:0,causalLinks:0},...meta};
    this.mutate(s=>s.replays.unshift(r));return r;
  }
  importKnowledge(filePath){
    const raw=JSON.parse(fs.readFileSync(filePath,'utf8')),cards=Array.isArray(raw)?raw:(raw.cards||[]);let added=0;
    this.mutate(s=>{const known=new Set(s.knowledge.cards.map(c=>String(c.id??c.name)));for(const c of cards){const k=String(c.id??c.name??'');if(!k||known.has(k))continue;s.knowledge.cards.push(c);known.add(k);added++}});return{added,totalInput:cards.length}
  }
  replaceKnowledgeCards(cards,relations=[]){return this.mutate(s=>{s.knowledge.cards=cards;s.knowledge.cardRelations=relations})}
  startSession(sourceGame,mode,meta={}){
    const id=`session_${Date.now()}_${Math.random().toString(16).slice(2,8)}`,eventFile=path.join(this.sessionsDir,`${id}.jsonl`),semanticFile=path.join(this.sessionsDir,`${id}.semantic.jsonl`);
    fs.writeFileSync(eventFile,'','utf8');fs.writeFileSync(semanticFile,'','utf8');
    const x={id,sourceGame,mode,startedAt:new Date().toISOString(),endedAt:null,eventCount:0,semanticFactCount:0,causalLinkCount:0,status:'running',eventFile:path.basename(eventFile),semanticFile:path.basename(semanticFile),...meta};this.mutate(s=>s.liveSessions.unshift(x));return x;
  }
  appendEvent(id,event){let out;this.mutate(s=>{const x=s.liveSessions.find(v=>v.id===id);if(!x||x.status!=='running')throw new Error('No active session');out={index:x.eventCount+1,at:new Date().toISOString(),...event};fs.appendFileSync(path.join(this.sessionsDir,x.eventFile),JSON.stringify(out)+'\n','utf8');x.eventCount++});return out}
  recordSemanticOutput(sessionId,output){
    if(!output)return null;let saved;
    this.mutate(s=>{
      const x=s.liveSessions.find(v=>v.id===sessionId);if(!x)throw new Error('Session not found');
      const facts=output.facts||[],links=output.links||[];
      const factIds=new Set(s.knowledge.semanticFacts.map(f=>f.id)),linkIds=new Set(s.knowledge.causalLinks.map(l=>l.id));
      for(const f of facts)if(!factIds.has(f.id)){s.knowledge.semanticFacts.push({...f,sessionId});factIds.add(f.id)}
      for(const l of links)if(!linkIds.has(l.id)){s.knowledge.causalLinks.push({...l,sessionId});linkIds.add(l.id)}
      x.semanticFactCount=(x.semanticFactCount||0)+facts.length;x.causalLinkCount=(x.causalLinkCount||0)+links.length;
      saved={event:output.event,facts,links,capabilities:output.capabilities||[]};
      fs.appendFileSync(path.join(this.sessionsDir,x.semanticFile),JSON.stringify(saved)+'\n','utf8');
    });return saved;
  }
  stopSession(id){let out;this.mutate(s=>{const x=s.liveSessions.find(v=>v.id===id);if(!x)throw new Error('Session not found');x.status='completed';x.endedAt=new Date().toISOString();out=x});return out}
  updateSettings(patch){return this.mutate(s=>{Object.assign(s.settings,patch);if(patch.masterDuelInstallPath)s.masterDuel.installPath=patch.masterDuelInstallPath}).settings}
  updateMasterDuelScan(scan){return this.mutate(s=>{s.masterDuel.installPath=scan.root;s.settings.masterDuelInstallPath=scan.root;s.masterDuel.lastScan=scan}).masterDuel}
  updateWatch(patch){return this.mutate(s=>Object.assign(s.masterDuel.watch,patch)).masterDuel.watch}
}
module.exports={Storage};
