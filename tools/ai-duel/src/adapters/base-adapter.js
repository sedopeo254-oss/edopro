class DuelAdapter { constructor(name){this.name=name} capabilities(){return{replay:false,live:false,cardDatabase:false}} async parseReplay(){throw new Error('parseReplay not implemented')} async startLive(){throw new Error('startLive not implemented')} async stopLive(){} }
module.exports={DuelAdapter};
