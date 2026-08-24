const{DuelAdapter}=require('./base-adapter');
class MasterDuelAdapter extends DuelAdapter{constructor(){super('Master Duel')}capabilities(){return{replay:'scaffold',live:'bridge-ready',cardDatabase:'import-ready'}}}
module.exports={MasterDuelAdapter};
