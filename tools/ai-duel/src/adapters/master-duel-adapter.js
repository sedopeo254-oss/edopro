'use strict';
const fs=require('fs');
const fsp=fs.promises;
const path=require('path');
const {DuelAdapter}=require('./base-adapter');

const DEFAULT_STEAM_PATH='C:\\Program Files (x86)\\Steam\\steamapps\\common\\Yu-Gi-Oh! Master Duel';
const CARD_BUNDLE_HINTS={
  cardDesc:['0000','d2','d25874ab'],
  cardIndex:['0000','a3','a3810eed'],
  cardName:['0000','87','87cea6f9'],
  cardPart:['0000','a1','a185f6c5'],
  cardPidx:['0000','ba','bab85e81']
};

function exists(p){try{return fs.existsSync(p)}catch{return false}}
function fileStat(p){try{const s=fs.statSync(p);return{exists:true,size:s.size,mtime:s.mtime.toISOString(),isDirectory:s.isDirectory()}}catch{return{exists:false}}}
function normalizeRoot(root){
  let p=String(root||'').trim().replace(/^\"|\"$/g,'');
  p=p.replace(/[\\/]+$/,'');
  return p;
}
function safeDirs(dir){try{return fs.readdirSync(dir,{withFileTypes:true}).filter(x=>x.isDirectory()).map(x=>x.name)}catch{return[]}}
function accountDirs(localData){return safeDirs(localData).filter(n=>/^[a-z0-9]{7,16}$/i.test(n));}

async function walkStats(root,{maxFiles=100000,maxDepth=8}={}){
  if(!exists(root))return{files:0,bytes:0,truncated:false,newest:null};
  let files=0,bytes=0,truncated=false,newest=0;
  const stack=[{dir:root,depth:0}];
  while(stack.length){
    const {dir,depth}=stack.pop();
    let entries=[];try{entries=await fsp.readdir(dir,{withFileTypes:true})}catch{continue}
    for(const e of entries){
      if(files>=maxFiles){truncated=true;break}
      const full=path.join(dir,e.name);
      if(e.isDirectory()&&depth<maxDepth){stack.push({dir:full,depth:depth+1});continue}
      if(!e.isFile())continue;
      try{const st=await fsp.stat(full);files++;bytes+=st.size;newest=Math.max(newest,st.mtimeMs)}catch{}
    }
    if(truncated)break;
  }
  return{files,bytes,truncated,newest:newest?new Date(newest).toISOString():null};
}

class MasterDuelAdapter extends DuelAdapter{
  constructor(){super('Master Duel')}
  capabilities(){return{
    replay:'json/replay-source detection + semantic reconstruction',
    live:'read-only source watcher; exact command bridge requires replay/duel event source',
    cardDatabase:'Steam LocalData discovery + imported/extracted card semantics',
    steamInstall:'auto-detect and validate'
  }}
  defaultInstallPath(){return DEFAULT_STEAM_PATH}
  candidateRoots(preferred){
    const roots=[normalizeRoot(preferred),DEFAULT_STEAM_PATH,
      'C:\\Program Files\\Steam\\steamapps\\common\\Yu-Gi-Oh! Master Duel'];
    return [...new Set(roots.filter(Boolean))];
  }
  detectInstall(preferred){
    for(const root of this.candidateRoots(preferred)){
      if(exists(path.join(root,'masterduel.exe'))||exists(path.join(root,'MasterDuel.exe'))||exists(path.join(root,'masterduel_Data')))return root;
    }
    return normalizeRoot(preferred)||DEFAULT_STEAM_PATH;
  }
  inspectInstall(root){
    root=this.detectInstall(root);
    const exeCandidates=['masterduel.exe','MasterDuel.exe','Yu-Gi-Oh! Master Duel.exe'].map(n=>path.join(root,n));
    const exe=exeCandidates.find(exists)||exeCandidates[0];
    const dataDir=path.join(root,'masterduel_Data');
    const duelDll=path.join(dataDir,'Plugins','x86_64','duel.dll');
    const gameAssembly=path.join(root,'GameAssembly.dll');
    const localData=path.join(root,'LocalData');
    const localSave=path.join(root,'LocalSave');
    const streamingAssets=path.join(dataDir,'StreamingAssets','AssetBundle');
    const accounts=accountDirs(localData).map(name=>{
      const base=path.join(localData,name);
      const hints={};
      for(const[k,parts]of Object.entries(CARD_BUNDLE_HINTS)){const p=path.join(base,...parts);hints[k]={path:p,...fileStat(p)}}
      return{name,path:base,contentRoot:path.join(base,'0000'),cardBundleHints:hints};
    });
    const ygoMasterRoot=path.join(root,'YgoMaster');
    const ygoMasterReplays=path.join(ygoMasterRoot,'Data','Players','Local','Replays');
    const ygoMasterDuelLog=path.join(ygoMasterRoot,'Data','ClientData','DuelLog.txt');
    return{
      root,
      valid:exists(exe)&&exists(dataDir),
      exe:{path:exe,...fileStat(exe)},
      dataDir:{path:dataDir,...fileStat(dataDir)},
      duelEngine:{path:duelDll,...fileStat(duelDll)},
      gameAssembly:{path:gameAssembly,...fileStat(gameAssembly)},
      localData:{path:localData,...fileStat(localData)},
      localSave:{path:localSave,...fileStat(localSave)},
      streamingAssets:{path:streamingAssets,...fileStat(streamingAssets)},
      accounts,
      ygoMaster:{
        installed:exists(ygoMasterRoot),root:ygoMasterRoot,
        replays:{path:ygoMasterReplays,...fileStat(ygoMasterReplays)},
        duelLog:{path:ygoMasterDuelLog,...fileStat(ygoMasterDuelLog)}
      },
      safety:{mode:'read-only',writesToGame:false,processInjection:false,hiddenInfo:false}
    };
  }
  async deepScan(root){
    const info=this.inspectInstall(root);
    const accountStats=[];
    for(const a of info.accounts){
      accountStats.push({name:a.name,...await walkStats(a.contentRoot,{maxFiles:80000,maxDepth:5})});
    }
    const streaming=await walkStats(info.streamingAssets.path,{maxFiles:20000,maxDepth:6});
    return{...info,scanAt:new Date().toISOString(),accountStats,streamingStats:streaming};
  }
  listReplayFiles(info){
    const dir=info?.ygoMaster?.replays?.path;
    if(!dir||!exists(dir))return[];
    try{return fs.readdirSync(dir,{withFileTypes:true}).filter(e=>e.isFile()&&/\.(json|jsonl|replay)$/i.test(e.name)).map(e=>{
      const p=path.join(dir,e.name),st=fs.statSync(p);return{path:p,name:e.name,size:st.size,mtime:st.mtime.toISOString()};
    }).sort((a,b)=>String(b.mtime).localeCompare(String(a.mtime)))}catch{return[]}
  }
}

module.exports={MasterDuelAdapter,DEFAULT_STEAM_PATH,CARD_BUNDLE_HINTS};
