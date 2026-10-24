export type Actor={Model:Model,Player:Player?,Role:string,Team:string,Alive:boolean,Energy:number,
 Stamina:number,Ultimate:number,Abilities:{string},Cooldowns:{[string]:number}}
export type RoundState="WaitingForPlayers"|"Intermission"|"VotingOrSelection"|"Loading"|"Intro"|"InProgress"|"SuddenDeath"|"Results"|"Cleanup"
return {}
