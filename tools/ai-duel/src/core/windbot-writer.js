'use strict';
const fs=require('fs');
const path=require('path');
function clean(v){return String(v??'').replace(/[\t\r\n]+/g,' ').trim()}
function mkdir(p){fs.mkdirSync(p,{recursive:true})}
function outcome(v){
  if(typeof v==='string'){
    const s=v.trim().toUpperCase();
    if(s==='WIN'||s==='WON'||s==='VICTORY')return'win';
    if(s==='LOSE'||s==='LOSS'||s==='LOST'||s==='DEFEAT')return'loss';
    return null;
  }
  const n=Number(v);
  if(n===1)return'win';      // YgoMaster DuelResultType.Win
  if(n===2)return'loss';     // YgoMaster DuelResultType.Lose
  return null;
}
class WindBotWriter{
  constructor(root){
    this.dir=path.join(root,'data','windbot');mkdir(this.dir);
    this.files={
      raw:path.join(this.dir,'AiDuel.BridgeRaw.jsonl'),
      experience:path.join(this.dir,'AiDuel.Experience.jsonl'),
      knowledge:path.join(this.dir,'AiDuel.Knowledge.json'),
      actions:path.join(this.dir,'AiDuel.ActionMemory.tsv'),
      decisions:path.join(this.dir,'AiDuel.Decisions.tsv'),
      sequences:path.join(this.dir,'AiDuel.Sequences.jsonl')
    };
    this.knowledge=this.loadKnowledge();this.sequence=null;
    if(!fs.existsSync(this.files.decisions))fs.writeFileSync(this.files.decisions,'session\tat\tturn\tphase\tplayer\taction\tcommandId\tcard\tcardName\trole\tfrom\tlp0\tlp1\thand0\thand1\tresult\tconfidence\tnote\n');
  }
  loadKnowledge(){try{return JSON.parse(fs.readFileSync(this.files.knowledge,'utf8'))}catch{return{version:3,updatedAt:null,sessions:0,events:0,actions:{},cards:{}}}}
  append(file,obj){fs.appendFileSync(file,JSON.stringify(obj)+'\n','utf8')}
  raw(msg){this.append(this.files.raw,msg)}
  begin(msg){this.sequence={session:msg.session||msg.sessionId||`duel_${Date.now()}`,startedAt:msg.at||new Date().toISOString(),events:[],result:null};this.knowledge.sessions=(this.knowledge.sessions||0)+1}
  event(ev){
    this.append(this.files.experience,ev);this.knowledge.events=(this.knowledge.events||0)+1;
    if(this.sequence)this.sequence.events.push({at:ev.at,turn:ev.turn,phase:ev.phase,player:ev.player,action:ev.action,cardId:ev.cardId,cardName:ev.cardName,role:ev.role,result:ev.result});
    const key=[ev.phase??'',ev.action??'',ev.cardId??''].join('|');
    const a=this.knowledge.actions[key]||{phase:ev.phase??null,action:ev.action||'UNKNOWN',cardId:ev.cardId??null,cardName:ev.cardName||'',samples:0,wins:0,losses:0};a.samples++;this.knowledge.actions[key]=a;
    if(ev.cardId){const ck=String(ev.cardId),c=this.knowledge.cards[ck]||{id:ev.cardId,name:ev.cardName||'',seen:0,wins:0,losses:0,actions:{}};c.seen++;c.actions[ev.action]=(c.actions[ev.action]||0)+1;this.knowledge.cards[ck]=c}
    const s=ev.state||{},lp=s.lp||[],hand=s.hand||[];
    const row=[ev.session,ev.at,ev.turn,ev.phase,ev.player,ev.action,ev.commandId,ev.cardId,ev.cardName,ev.role,ev.from,lp[0],lp[1],hand[0],hand[1],ev.result,ev.confidence,ev.note].map(clean).join('\t')+'\n';
    fs.appendFileSync(this.files.decisions,row,'utf8');
  }
  applyOutcome(seq,result){
    const o=outcome(result);if(!o||!seq)return;
    const seenActions=new Set(),seenCards=new Set();
    for(const ev of seq.events||[]){
      const key=[ev.phase??'',ev.action??'',ev.cardId??''].join('|');
      if(!seenActions.has(key)&&this.knowledge.actions[key]){
        this.knowledge.actions[key][o==='win'?'wins':'losses']++;
        seenActions.add(key);
      }
      if(ev.cardId!=null){
        const ck=String(ev.cardId),c=this.knowledge.cards[ck];
        if(c&&!seenCards.has(ck)){c[o==='win'?'wins':'losses']=(c[o==='win'?'wins':'losses']||0)+1;seenCards.add(ck)}
      }
    }
  }
  end(msg){
    if(this.sequence){
      this.sequence.endedAt=msg.at||new Date().toISOString();this.sequence.result=msg.result??msg.res??null;
      this.sequence.finish=msg.finish??null;this.sequence.finishCardId=msg.finishCardId??null;
      this.applyOutcome(this.sequence,this.sequence.result);this.append(this.files.sequences,this.sequence);this.sequence=null;
    }
    this.flush();
  }
  flush(){
    this.knowledge.updatedAt=new Date().toISOString();fs.writeFileSync(this.files.knowledge,JSON.stringify(this.knowledge,null,2),'utf8');
    const rows=['phase\taction\tcard\tcardName\tsamples\twins\tlosses'];
    for(const a of Object.values(this.knowledge.actions))rows.push([a.phase,a.action,a.cardId,a.cardName,a.samples,a.wins,a.losses].map(clean).join('\t'));
    fs.writeFileSync(this.files.actions,rows.join('\n')+'\n','utf8');
  }
}
module.exports={WindBotWriter};
