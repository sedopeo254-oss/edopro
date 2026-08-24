'use strict';
const {parseCardSemantics}=require('./semantic-engine');

const ROLE_RULES=[
  ['searcher',/add .* from (?:your )?deck|search/i],
  ['draw-engine',/\bdraw\b/i],
  ['special-summon',/special summon/i],
  ['normal-summon-support',/normal summon|additional normal summon/i],
  ['tribute-engine',/tribute summon|\btribute\b/i],
  ['negate',/\bnegate\b/i],
  ['removal-destroy',/\bdestroy\b/i],
  ['removal-banish',/\bbanish\b/i],
  ['removal-bounce',/return .* to (?:the )?(?:hand|deck|extra deck)/i],
  ['graveyard-engine',/graveyard|\bGY\b|sent to the gy/i],
  ['extender',/if you control|you can special summon this card/i],
  ['interaction',/quick effect|when your opponent|during your opponent/i],
  ['otk-pressure',/attack twice|second attack|double.*damage/i],
  ['burn',/inflict .* damage/i],
  ['recovery',/add .* from .*graveyard|target .* in your gy.*add|special summon .* from .*gy/i],
  ['starter',/add .* from (?:your )?deck|send .* from (?:your )?deck|special summon .* from (?:your )?deck/i]
];

function textOf(card){return String(card?.text||card?.desc||card?.effect||'')}
function inferCardRoles(card){
  const t=textOf(card),roles=[];
  for(const [n,r] of ROLE_RULES)if(r.test(t))roles.push(n);
  return [...new Set(roles)];
}
function analyzeCards(cards){
  const analyzed=cards.map(c=>{
    const semantics=parseCardSemantics(c);
    return {...c,inferredRoles:inferCardRoles(c),semantic:semantics};
  });
  const roleCounts={},operationCounts={},triggerCounts={};
  for(const c of analyzed){
    for(const r of c.inferredRoles)roleCounts[r]=(roleCounts[r]||0)+1;
    for(const fx of c.semantic?.effects||[]){
      triggerCounts[fx.trigger]=(triggerCounts[fx.trigger]||0)+1;
      for(const op of fx.operations||[])operationCounts[op]=(operationCounts[op]||0)+1;
    }
  }
  return{analyzed,roleCounts,operationCounts,triggerCounts};
}

function inferCardRelations(cards){
  const relations=[];
  const byName=new Map(cards.filter(c=>c?.name).map(c=>[String(c.name).toLowerCase(),c]));
  for(const c of cards){
    const t=textOf(c);
    for(const [name,target] of byName){
      if(target===c||name.length<4)continue;
      if(t.toLowerCase().includes(`\"${name}\"`)||t.toLowerCase().includes(name)){
        relations.push({from:c.id??c.name,to:target.id??target.name,type:'mentions-card',confidence:.98});
      }
    }
    const quoted=[...t.matchAll(/\"([^\"]{2,80})\"/g)].map(m=>m[1]);
    for(const q of quoted){
      if(byName.has(q.toLowerCase()))continue;
      relations.push({from:c.id??c.name,to:q,type:'mentions-archetype-or-name',confidence:.7});
    }
  }
  return relations;
}

module.exports={inferCardRoles,analyzeCards,inferCardRelations};
