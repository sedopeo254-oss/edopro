'use strict';

const SUMMON_METHODS = new Set([
  'NORMAL','TRIBUTE','SPECIAL','RITUAL','FUSION','SYNCHRO','XYZ','PENDULUM','LINK','FLIP'
]);

function textOf(card){ return String(card?.text ?? card?.desc ?? card?.effect ?? ''); }
function cardKey(card){ return String(card?.id ?? card?.cardId ?? card?.name ?? '').trim(); }
function cardName(card){ return String(card?.name ?? card?.cardName ?? card?.id ?? card?.cardId ?? 'Unknown card'); }
function upper(v){ return String(v ?? '').trim().toUpperCase().replace(/[ -]+/g,'_'); }
function uniq(arr){ return [...new Set((arr||[]).filter(Boolean))]; }
function id(prefix='evt'){ return `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2,10)}`; }

const OPERATIONS = [
  ['draw', /\bdraw\b/i],
  ['search', /add .* from (?:your )?deck|add .* deck .* to (?:your )?hand/i],
  ['special-summon', /special summon/i],
  ['normal-summon', /normal summon/i],
  ['tribute', /\btribute\b/i],
  ['send-to-gy', /send .* to (?:the )?(?:gy|graveyard)/i],
  ['discard', /\bdiscard\b/i],
  ['destroy', /\bdestroy\b/i],
  ['banish', /\bbanish\b/i],
  ['negate', /\bnegate\b/i],
  ['return-hand', /return .* to (?:the )?hand/i],
  ['return-deck', /return .* to (?:the )?(?:deck|extra deck)/i],
  ['change-position', /change .* battle position|change .* to (?:face-up|face-down|attack|defense)/i],
  ['gain-lp', /gain .* lp|gain .* life points/i],
  ['damage', /inflict .* damage|take .* damage/i],
  ['mill', /send the top .* cards? of .* deck/i],
  ['equip', /equip .* to/i],
  ['attach-material', /attach .* as material/i],
  ['detach-material', /detach .* material/i]
];

function inferOperations(text){
  const out=[];
  for(const [name,re] of OPERATIONS) if(re.test(text)) out.push(name);
  return uniq(out);
}

function inferTrigger(text){
  const t=String(text||'');
  const rules=[
    ['on-tribute-summon', /if this card is tribute summoned|when this card is tribute summoned/i],
    ['on-normal-summon', /if this card is normal summoned|when this card is normal summoned/i],
    ['on-special-summon', /if this card is special summoned|when this card is special summoned/i],
    ['on-summon', /if this card is summoned|when this card is summoned/i],
    ['on-fusion-summon', /if this card is fusion summoned|when this card is fusion summoned/i],
    ['on-synchro-summon', /if this card is synchro summoned|when this card is synchro summoned/i],
    ['on-xyz-summon', /if this card is xyz summoned|when this card is xyz summoned/i],
    ['on-link-summon', /if this card is link summoned|when this card is link summoned/i],
    ['on-destroyed', /if this card is destroyed|when this card is destroyed/i],
    ['on-sent-to-gy', /if this card is sent to (?:the )?(?:gy|graveyard)|when this card is sent to (?:the )?(?:gy|graveyard)/i],
    ['on-banish', /if this card is banished|when this card is banished/i],
    ['quick', /\(quick effect\)|during either player'?s turn/i],
    ['ignition', /once per turn:|you can .*;/i]
  ];
  for(const [name,re] of rules) if(re.test(t)) return name;
  return 'unknown';
}

function splitEffects(text){
  const t=String(text||'').replace(/\r/g,'').trim();
  if(!t) return [];
  const lines=t.split(/\n+/).map(x=>x.trim()).filter(Boolean);
  return lines.length ? lines : [t];
}

function parseEffectClause(clause,index=0){
  const colon=clause.indexOf(':');
  const semi=clause.indexOf(';');
  let condition='',costTarget='',operation=clause;
  if(colon>=0){ condition=clause.slice(0,colon).trim(); operation=clause.slice(colon+1).trim(); }
  if(semi>=0){
    const start=colon>=0?colon+1:0;
    costTarget=clause.slice(start,semi).trim();
    operation=clause.slice(semi+1).trim();
  }
  return {
    index,
    raw:clause,
    trigger:inferTrigger(clause),
    condition,
    costTarget,
    operation,
    operations:inferOperations(operation || clause),
    costs:inferOperations(costTarget),
    oncePerTurn:/once per turn|only use this effect .* once per turn/i.test(clause)
  };
}

function parseCardSemantics(card){
  const text=textOf(card);
  return {
    key:cardKey(card), name:cardName(card), text,
    effects:splitEffects(text).map(parseEffectClause),
    operations:inferOperations(text)
  };
}

function normalizeCard(raw){
  if(!raw) return null;
  if(typeof raw==='string' || typeof raw==='number') return {name:String(raw)};
  return {
    id: raw.id ?? raw.cardId ?? raw.code ?? null,
    name: raw.name ?? raw.cardName ?? raw.label ?? null,
    level: raw.level ?? null,
    location: raw.location ?? raw.zone ?? null,
    controller: raw.controller ?? raw.player ?? null
  };
}

function normalizeEvent(raw,index=0){
  const type=upper(raw?.type || raw?.event || raw?.kind || 'UNKNOWN');
  const summonMethodRaw=raw?.summonMethod ?? raw?.summon?.method ?? raw?.method;
  let summonMethod=upper(summonMethodRaw);
  if(summonMethod==='TRIBUTE_SUMMON') summonMethod='TRIBUTE';
  if(summonMethod==='NORMAL_SUMMON') summonMethod='NORMAL';
  if(!SUMMON_METHODS.has(summonMethod)) summonMethod=null;
  const materials=(raw?.materials ?? raw?.tributes ?? raw?.summon?.materials ?? []).map(normalizeCard).filter(Boolean);
  return {
    id: raw?.id || id('event'), index: raw?.index ?? index,
    at: raw?.at || new Date().toISOString(),
    type,
    player: raw?.player ?? raw?.controller ?? null,
    card: normalizeCard(raw?.card || (raw?.cardName ? {name:raw.cardName,id:raw.cardId}:null)),
    sourceCard: normalizeCard(raw?.sourceCard || raw?.source),
    targetCards:(raw?.targetCards ?? raw?.targets ?? []).map(normalizeCard).filter(Boolean),
    from: upper(raw?.from || raw?.fromZone || raw?.previousLocation) || null,
    to: upper(raw?.to || raw?.toZone || raw?.location) || null,
    reason: upper(raw?.reason || raw?.moveReason) || null,
    summonMethod,
    materials,
    count:Number(raw?.count ?? raw?.amount ?? 0) || null,
    effectIndex: raw?.effectIndex ?? raw?.effect?.index ?? null,
    note: raw?.note || '',
    raw
  };
}

function isTributeMove(e){
  return ['MOVE','SEND_TO_GY','RELEASE','TRIBUTE'].includes(e.type) && (e.reason==='TRIBUTE' || e.type==='TRIBUTE' || e.type==='RELEASE');
}
function samePlayer(a,b){ return a.player == null || b.player == null || a.player===b.player; }
function sameCard(a,b){
  const ak=cardKey(a),bk=cardKey(b);
  return !!ak && !!bk && ak===bk;
}

function inferSummonMethod(event,history){
  if(event.summonMethod) return {method:event.summonMethod,confidence:1,evidence:[]};
  if(!['SUMMON','NORMAL_SUMMON','TRIBUTE_SUMMON','SPECIAL_SUMMON'].includes(event.type)) return {method:null,confidence:0,evidence:[]};
  if(event.type==='TRIBUTE_SUMMON') return {method:'TRIBUTE',confidence:1,evidence:[]};
  if(event.type==='SPECIAL_SUMMON') return {method:'SPECIAL',confidence:1,evidence:[]};
  const recent=history.slice(-6).filter(x=>samePlayer(x,event));
  const tributeEvents=recent.filter(isTributeMove);
  if(tributeEvents.length){
    return {method:'TRIBUTE',confidence:.92,evidence:tributeEvents.map(x=>x.id)};
  }
  if(event.type==='NORMAL_SUMMON') return {method:'NORMAL',confidence:.98,evidence:[]};
  return {method:'UNKNOWN',confidence:.25,evidence:[]};
}

function triggerMatches(method,trigger){
  if(trigger==='on-summon') return !!method && method!=='UNKNOWN';
  if(trigger==='on-tribute-summon') return method==='TRIBUTE';
  if(trigger==='on-normal-summon') return method==='NORMAL' || method==='TRIBUTE';
  if(trigger==='on-special-summon') return method==='SPECIAL';
  if(trigger==='on-fusion-summon') return method==='FUSION';
  if(trigger==='on-synchro-summon') return method==='SYNCHRO';
  if(trigger==='on-xyz-summon') return method==='XYZ';
  if(trigger==='on-link-summon') return method==='LINK';
  return false;
}

class SemanticDuelEngine {
  constructor(cards=[]){
    this.cards=new Map();
    for(const c of cards||[]){ const k=cardKey(c); if(k) this.cards.set(k,c); if(c?.name) this.cards.set(String(c.name),c); }
    this.reset();
  }
  reset(){ this.events=[]; this.links=[]; this.facts=[]; this.pendingActivations=[]; this.capabilities=[]; }
  lookup(card){
    if(!card) return null;
    return this.cards.get(cardKey(card)) || this.cards.get(cardName(card)) || null;
  }
  addLink(type,from,to,confidence=1,reason=''){
    if(!from||!to) return null;
    const key=`${type}:${from}:${to}`;
    if(this.links.some(x=>x.key===key)) return null;
    const l={key,id:id('link'),type,from,to,confidence,reason}; this.links.push(l); return l;
  }
  addFact(kind,eventId,text,confidence=1,data={}){
    const f={id:id('fact'),kind,eventId,text,confidence,data,at:new Date().toISOString()};
    this.facts.push(f); return f;
  }
  recent(n=10){ return this.events.slice(-n); }
  ingest(raw){
    const e=normalizeEvent(raw,this.events.length+1);
    const before=this.events.slice();
    const output={event:e,links:[],facts:[],capabilities:[]};

    if(['SUMMON','NORMAL_SUMMON','TRIBUTE_SUMMON','SPECIAL_SUMMON'].includes(e.type)){
      const inf=inferSummonMethod(e,before);
      e.summonMethod=inf.method;
      const recentTributes=before.slice(-8).filter(x=>isTributeMove(x)&&samePlayer(x,e));
      if(e.summonMethod==='TRIBUTE' && !e.materials.length){
        e.materials=recentTributes.map(x=>x.card).filter(Boolean);
      }
      for(const t of recentTributes){ const l=this.addLink('consumed-by',t.id,e.id,.94,'Tributed/released immediately before summon'); if(l) output.links.push(l); }
      const matNames=e.materials.map(cardName).filter(Boolean);
      const label=e.summonMethod==='TRIBUTE'?'Tribute Summoned':`${e.summonMethod||'Unknown'} Summoned`;
      const detail=matNames.length?` by tributing ${matNames.join(' + ')}`:'';
      output.facts.push(this.addFact('summon',e.id,`${label} ${cardName(e.card)}${detail}.`,inf.confidence,{method:e.summonMethod,materials:e.materials}));

      const dbCard=this.lookup(e.card);
      if(dbCard){
        const semantics=parseCardSemantics(dbCard);
        for(const fx of semantics.effects){
          if(triggerMatches(e.summonMethod,fx.trigger)){
            const cap={id:id('cap'),card:e.card,effectIndex:fx.index,trigger:fx.trigger,operations:fx.operations,enabledBy:e.id,confidence:.9,text:fx.raw};
            this.capabilities.push(cap); output.capabilities.push(cap);
            const l=this.addLink('enabled-effect',e.id,cap.id,.9,`Summon method ${e.summonMethod} matches ${fx.trigger}`); if(l) output.links.push(l);
            output.facts.push(this.addFact('effect-enabled',e.id,`${cardName(e.card)} now has an enabled ${fx.trigger} effect${fx.operations.length?` (${fx.operations.join(', ')})`:''}.`,.9,{capability:cap}));
          }
        }
      }
    }

    if(['ACTIVATE','EFFECT_ACTIVATE','CHAIN'].includes(e.type)){
      const dbCard=this.lookup(e.card||e.sourceCard);
      let fx=null;
      if(dbCard){ const sem=parseCardSemantics(dbCard); fx=e.effectIndex!=null?sem.effects[e.effectIndex]:sem.effects[0]||null; }
      const matchingCaps=this.capabilities.filter(c=>sameCard(c.card,e.card||e.sourceCard));
      const cap=matchingCaps.at(-1);
      if(cap){ const l=this.addLink('enabled-by',cap.enabledBy,e.id,.92,'Activation uses an effect enabled by prior game event'); if(l) output.links.push(l); }
      const activation={eventId:e.id,card:e.card||e.sourceCard,operations:fx?.operations||cap?.operations||[],effectIndex:e.effectIndex,capabilityId:cap?.id||null};
      this.pendingActivations.push(activation);
      output.facts.push(this.addFact('activation',e.id,`Activated ${cardName(activation.card)}${activation.operations.length?` to ${activation.operations.join(', ')}`:''}.`,fx?.operations?.length?.95:.65,{activation}));
    }

    const outcomeMap={DRAW:'draw',ADD_TO_HAND:'search',SPECIAL_SUMMON:'special-summon',DESTROY:'destroy',BANISH:'banish',NEGATE:'negate',DAMAGE:'damage'};
    const operation=outcomeMap[e.type] || (e.type==='MOVE'&&e.to==='HAND'?'search':null);
    if(operation){
      const activation=[...this.pendingActivations].reverse().find(a=>a.operations.includes(operation) || (!a.operations.length && this.events.length && this.events.at(-1)?.type?.includes('ACTIVATE')));
      if(activation){
        const l=this.addLink('caused-by',activation.eventId,e.id,activation.operations.includes(operation)?.97:.7,`${operation} matches activated card effect operation`); if(l) output.links.push(l);
        if(operation==='draw') output.facts.push(this.addFact('effect-result',e.id,`${cardName(activation.card)} caused Player ${e.player ?? '?'} to draw ${e.count||1} card(s).`,.97,{sourceActivation:activation.eventId,count:e.count||1}));
        else output.facts.push(this.addFact('effect-result',e.id,`${cardName(activation.card)} produced ${operation}.`,.9,{sourceActivation:activation.eventId}));
      }
    }

    if(operation==='draw'){
      const cause=output.links.find(x=>x.type==='caused-by');
      if(cause){
        const activationEvent=this.events.find(x=>x.id===cause.from);
        const priorEnable=this.links.find(x=>x.type==='enabled-by' && x.to===cause.from);
        const summonEvent=priorEnable?this.events.find(x=>x.id===priorEnable.from):null;
        if(summonEvent){
          const mats=(summonEvent.materials||[]).map(cardName);
          const text=`Sequence understood: ${cardName(summonEvent.card)} was ${summonEvent.summonMethod==='TRIBUTE'?'Tribute Summoned':'Summoned'}${mats.length?` using ${mats.join(' + ')}`:''}; that summon enabled its effect; activating it then caused the draw.`;
          output.facts.push(this.addFact('causal-sequence',e.id,text,.94,{summonEvent:summonEvent.id,activationEvent:activationEvent?.id,resultEvent:e.id}));
        }
      }
    }

    this.events.push(e);
    return output;
  }
  ingestMany(events){ return (events||[]).map(e=>this.ingest(e)); }
  snapshot(){ return {events:this.events,links:this.links,facts:this.facts,capabilities:this.capabilities}; }
}

module.exports={SemanticDuelEngine,normalizeEvent,parseCardSemantics,inferOperations,inferSummonMethod};
