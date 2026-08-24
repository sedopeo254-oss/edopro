'use strict';
const net=require('net');
const{EventEmitter}=require('events');
const{WindBotWriter}=require('./windbot-writer');
const PHASE={0:'DRAW',1:'STANDBY',2:'MAIN1',3:'BATTLE',4:'MAIN2',5:'END',7:'NULL'};
const CMD={0:'ATTACK_INTENT',1:'LOOK_INTENT',2:'SPECIAL_SUMMON_INTENT',3:'EFFECT_ACTIVATE_INTENT',4:'SUMMON_INTENT',5:'FLIP_SUMMON_INTENT',6:'SET_MONSTER_INTENT',7:'SET_INTENT',8:'PENDULUM_SUMMON_INTENT',9:'TO_ATTACK_INTENT',10:'TO_DEFENSE_INTENT',11:'SURRENDER_INTENT',12:'DECIDE_INTENT',13:'DRAW_INTENT'};
function now(){return new Date().toISOString()}
function num(v){const n=Number(v);return Number.isFinite(n)?n:null}
function cardOf(m){const c=m.card||m.sourceCard||{};return{id:c.id??c.cardId??m.cardId??m.sourceCardId??null,name:c.name??c.cardName??m.cardName??m.sourceCardName??''}}
function stateOf(m){const s=m.state||m.snapshot||{};const phaseValue=s.phase??m.phase??null;return{turn:num(s.turn??m.turn),phase:s.phaseName||PHASE[phaseValue]||phaseValue,lp:Array.isArray(s.lp)?s.lp:[s.lp0??null,s.lp1??null],hand:Array.isArray(s.hand)?s.hand:[s.hand0??null,s.hand1??null]}}
function roleFromAttr(v){v=Number(v)||0;if(v&131072)return'COST';if(v&256||v&8192)return'MATERIAL';if(v&4096)return'TARGET';return'SELECTION'}
class BridgeReceiver extends EventEmitter{
  constructor(root,port=17384){super();this.port=port;this.writer=new WindBotWriter(root);this.server=null;this.clients=0;this.messages=0;this.bad=0;this.connected=false;this.session=null;this.phase=null;this.turn=null}
  status(){return{running:!!this.server,connected:this.connected,clients:this.clients,messages:this.messages,badMessages:this.bad,port:this.port,outputDir:this.writer.dir}}
  start(){if(this.server)return Promise.resolve(this.status());return new Promise((resolve,reject)=>{const srv=net.createServer(s=>this.socket(s));srv.once('error',reject);srv.listen(this.port,'127.0.0.1',()=>{this.server=srv;resolve(this.status())})})}
  stop(){if(!this.server)return;try{this.server.close()}catch{}this.server=null;this.connected=false}
  socket(sock){this.clients++;this.connected=true;this.emit('status',this.status());let buf='';sock.setEncoding('utf8');sock.on('data',d=>{buf+=d;if(buf.length>2*1024*1024){buf='';this.bad++;return}let p;while((p=buf.indexOf('\n'))>=0){const line=buf.slice(0,p).trim();buf=buf.slice(p+1);if(line)this.line(line)}});sock.on('close',()=>{this.clients=Math.max(0,this.clients-1);this.connected=this.clients>0;this.emit('status',this.status())});sock.on('error',()=>{})}
  line(line){let m;try{m=JSON.parse(line)}catch{this.bad++;return}this.messages++;this.writer.raw(m);const t=String(m.type||m.kind||'').toUpperCase();if(t==='HELLO'){this.connected=true;this.emit('message',m);return}if(t==='DUEL_BEGIN'){this.session=m.session||m.sessionId||`duel_${Date.now()}`;this.writer.begin({...m,session:this.session});this.emit('message',m);return}if(t==='DUEL_END'){this.writer.end(m);this.emit('message',m);this.session=null;return}const ev=this.normalize(m,t);if(ev){this.writer.event(ev);this.emit('event',ev)}this.emit('status',this.status())}
  normalize(m,t){const s=stateOf(m);if(s.turn!=null)this.turn=s.turn;if(s.phase!=null)this.phase=s.phase;const c=cardOf(m);let action=t,role='',confidence=.75,result=m.result??'';
    if(t==='PHASE'){action='PHASE_CHANGE';this.phase=PHASE[m.phase]||m.phaseName||m.phase;confidence=1}
    else if(t==='COMMAND'){action=CMD[m.commandId]||`COMMAND_${m.commandId}`;role='INTENT';confidence=.99}
    else if(t==='LIST_SELECT'||t==='LIST_CARD_EX_DATA'){role=roleFromAttr(m.attribute??m.data);action=`${role}_SELECT`;confidence=.95}
    else if(t==='RUN_EFFECT'){action=m.action||m.viewName||`RUN_EFFECT_${m.id??m.viewType??''}`;role='RESOLUTION';confidence=.9}
    else if(t==='DIALOG_RESULT'){action='DIALOG_RESULT';role='DECISION';confidence=.99}
    return{session:m.session||m.sessionId||this.session||'',at:m.at||now(),turn:s.turn??this.turn,phase:s.phase??this.phase,player:m.player??m.controller??null,action,commandId:m.commandId??null,cardId:c.id,cardName:c.name,role,from:m.from??m.position??'',state:s,result,confidence,note:m.note||'',raw:m};
  }
}
module.exports={BridgeReceiver};
