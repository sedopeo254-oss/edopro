const fs = require('fs');
const path = require('path');

const EMPTY_STATE = {
  version: 1, createdAt: null,
  counters: { replays:0, liveSessions:0, events:0, decks:0, tacticalPatterns:0, comebackPatterns:0 },
  replays: [], liveSessions: [],
  knowledge: { cards: [], decks: [], patterns: [] },
  settings: { defaultSource:'Master Duel', observerMode:'Observer', autoAnalyzeImports:true, safeReadOnlyCapture:true }
};

class Storage {
  constructor(root){ this.root=root; this.dataDir=path.join(root,'data'); this.replaysDir=path.join(this.dataDir,'replays'); this.sessionsDir=path.join(this.dataDir,'sessions'); this.stateFile=path.join(this.dataDir,'state.json'); this.ensure(); }
  ensure(){ fs.mkdirSync(this.replaysDir,{recursive:true}); fs.mkdirSync(this.sessionsDir,{recursive:true}); if(!fs.existsSync(this.stateFile)){const s=structuredClone(EMPTY_STATE);s.createdAt=new Date().toISOString();this.write(s);} }
  normalize(s){const b=structuredClone(EMPTY_STATE);return {...b,...s,counters:{...b.counters,...(s.counters||{})},knowledge:{...b.knowledge,...(s.knowledge||{})},settings:{...b.settings,...(s.settings||{})},replays:Array.isArray(s.replays)?s.replays:[],liveSessions:Array.isArray(s.liveSessions)?s.liveSessions:[]};}
  read(){try{return this.normalize(JSON.parse(fs.readFileSync(this.stateFile,'utf8')))}catch{const s=structuredClone(EMPTY_STATE);s.createdAt=new Date().toISOString();this.write(s);return s}}
  write(s){fs.writeFileSync(this.stateFile,JSON.stringify(s,null,2),'utf8')}
  recount(s){s.counters.replays=s.replays.length;s.counters.liveSessions=s.liveSessions.length;s.counters.events=s.liveSessions.reduce((n,x)=>n+(x.eventCount||0),0);s.counters.decks=s.knowledge.decks.length;s.counters.tacticalPatterns=s.knowledge.patterns.length;s.counters.comebackPatterns=s.knowledge.patterns.filter(p=>p.kind==='comeback').length}
  mutate(fn){const s=this.read();fn(s);this.recount(s);this.write(s);return s}
  safeName(n){return n.replace(/[<>:\"/\\|?*\x00-\x1F]/g,'_').slice(0,180)}
  importReplay(sourcePath,sourceGame='Master Duel'){const st=fs.statSync(sourcePath),name=path.basename(sourcePath),stamp=Date.now(),stored=`${stamp}_${this.safeName(name)}`;fs.copyFileSync(sourcePath,path.join(this.replaysDir,stored));const r={id:`replay_${stamp}_${Math.random().toString(16).slice(2,8)}`,sourceGame,originalName:name,storedName:stored,importedAt:new Date().toISOString(),size:st.size,status:'Queued for adapter analysis',analysis:{events:0,turns:null,decks:[],patterns:[]}};this.mutate(s=>s.replays.unshift(r));return r}
  importKnowledge(filePath){const raw=JSON.parse(fs.readFileSync(filePath,'utf8')),cards=Array.isArray(raw)?raw:(raw.cards||[]);let added=0;this.mutate(s=>{const known=new Set(s.knowledge.cards.map(c=>String(c.id??c.name)));for(const c of cards){const k=String(c.id??c.name??'');if(!k||known.has(k))continue;s.knowledge.cards.push(c);known.add(k);added++;}});return{added,totalInput:cards.length}}
  startSession(sourceGame,mode){const id=`session_${Date.now()}_${Math.random().toString(16).slice(2,8)}`,eventFile=path.join(this.sessionsDir,`${id}.jsonl`);fs.writeFileSync(eventFile,'','utf8');const x={id,sourceGame,mode,startedAt:new Date().toISOString(),endedAt:null,eventCount:0,status:'running',eventFile:path.basename(eventFile)};this.mutate(s=>s.liveSessions.unshift(x));return x}
  appendEvent(id,event){let out;this.mutate(s=>{const x=s.liveSessions.find(v=>v.id===id);if(!x||x.status!=='running')throw new Error('No active session');out={index:x.eventCount+1,at:new Date().toISOString(),...event};fs.appendFileSync(path.join(this.sessionsDir,x.eventFile),JSON.stringify(out)+'\n','utf8');x.eventCount++;});return out}
  stopSession(id){let out;this.mutate(s=>{const x=s.liveSessions.find(v=>v.id===id);if(!x)throw new Error('Session not found');x.status='completed';x.endedAt=new Date().toISOString();out=x;});return out}
  updateSettings(patch){return this.mutate(s=>Object.assign(s.settings,patch)).settings}
}
module.exports={Storage};
