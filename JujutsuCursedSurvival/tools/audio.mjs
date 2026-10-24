// Original synthesized effects. Upload only under the experience owner's account.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../assets/Audio');fs.mkdirSync(root,{recursive:true});
let seed=81;const noise=()=>{seed=(seed*48271)%2147483647;return seed/2147483647*2-1;};
function wav(name,duration,fn){const rate=44100,n=Math.floor(rate*duration),b=Buffer.alloc(44+n*2);b.write('RIFF');b.writeUInt32LE(36+n*2,4);b.write('WAVE',8);b.write('fmt ',12);b.writeUInt32LE(16,16);b.writeUInt16LE(1,20);b.writeUInt16LE(1,22);b.writeUInt32LE(rate,24);b.writeUInt32LE(rate*2,28);b.writeUInt16LE(2,32);b.writeUInt16LE(16,34);b.write('data',36);b.writeUInt32LE(n*2,40);
for(let i=0;i<n;i++){const t=i/rate,fade=Math.min(1,t/.008,(duration-t)/.025);b.writeInt16LE(Math.round(Math.max(-.75,Math.min(.75,fn(t,duration)))*fade*24000),44+i*2);}fs.writeFileSync(path.join(root,name+'.wav'),b);}
wav('impact',.24,t=>(Math.sin(2*Math.PI*(150*t-180*t*t))*.6+noise()*.25)*Math.exp(-t*19));
wav('cast',.65,t=>(Math.sin(2*Math.PI*(280*t+360*t*t))*.35+Math.sin(2*Math.PI*560*t)*.1)*Math.sin(Math.PI*t/.65));
wav('domain',1.7,t=>(Math.sin(2*Math.PI*66*t)*.25+Math.sin(2*Math.PI*99*t)*.18+noise()*.04)*Math.sin(Math.PI*t/1.7));
wav('seal',.85,t=>[440,554.37,659.25].reduce((a,f)=>a+Math.sin(2*Math.PI*f*t)*.16,0)*Math.exp(-t*3));
wav('warning',.45,t=>(Math.sin(2*Math.PI*(90*t+90*t*t))*.35+noise()*.08)*Math.exp(-t*4));
console.log('Generated 5 original WAV files; no Roblox audio IDs assigned.');
