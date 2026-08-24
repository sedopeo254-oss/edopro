'use strict';
const{contextBridge,ipcRenderer}=require('electron');
const path=require('path');
const os=require('os');
const{BridgeReceiver}=require('./core/bridge-receiver');
const bridgeRoot=path.join(process.env.APPDATA||process.env.LOCALAPPDATA||os.homedir(),'Ai Duel');
const receiver=new BridgeReceiver(bridgeRoot,17384);
receiver.start().catch(()=>{});
contextBridge.exposeInMainWorld('aiDuel',{
  getState:()=>ipcRenderer.invoke('state:get'),
  importReplay:s=>ipcRenderer.invoke('replay:import',s),
  importKnowledge:()=>ipcRenderer.invoke('knowledge:import'),
  chooseMasterDuelFolder:()=>ipcRenderer.invoke('md:choose-folder'),
  inspectMasterDuel:p=>ipcRenderer.invoke('md:inspect',p),
  scanMasterDuel:p=>ipcRenderer.invoke('md:scan',p),
  openMasterDuelFolder:()=>ipcRenderer.invoke('md:open-game-folder'),
  startLive:p=>ipcRenderer.invoke('live:start',p),
  recordEvent:e=>ipcRenderer.invoke('live:event',e),
  stopLive:()=>ipcRenderer.invoke('live:stop'),
  runSemanticDemo:()=>ipcRenderer.invoke('semantic:demo'),
  updateSettings:p=>ipcRenderer.invoke('settings:update',p),
  openDataFolder:()=>ipcRenderer.invoke('data:open-folder'),
  appInfo:()=>ipcRenderer.invoke('app:info'),
  bridgeStatus:()=>receiver.status(),
  bridgeOutputPath:()=>receiver.writer.dir,
  onBridgeEvent:cb=>receiver.on('event',ev=>cb(ev)),
  onBridgeStatus:cb=>receiver.on('status',st=>cb(st)),
  onReplayCaptured:cb=>ipcRenderer.on('md:replay-captured',(_e,item)=>cb(item))
});
