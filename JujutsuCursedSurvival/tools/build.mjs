import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const args=process.argv.slice(2);
if(args.length===0){
 const result=spawnSync('rojo',['build','default.project.json','-o','test.rbxl'],{cwd:ROOT,stdio:'inherit'});
 if(result.error) console.error(result.error.message);
 process.exit(result.status ?? 1);
}
if(args.length!==3 || args[0]!=='--regenerate' || args[1]!=='--output'){
 console.error('Usage: node tools/build.mjs [--regenerate --output work/generated/NEW-NAME]');
 process.exit(1);
}
// Legacy procedural drafts are opt-in and can NEVER overwrite authored assets/project files.
const generatedRoot=path.join(ROOT,'work','generated');
const output=path.resolve(ROOT,args[2]);
if(path.dirname(output)!==generatedRoot || fs.existsSync(output)){
 throw new Error('Regeneration requires a NEW direct child of work/generated. Existing paths are refused.');
}
fs.mkdirSync(generatedRoot,{recursive:true});
if(fs.realpathSync(generatedRoot)!==generatedRoot) throw new Error('Redirected generation directory is not allowed');
fs.mkdirSync(output);
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
let serial=0;
const prop=(type,name,value)=>`<${type} name="${name}">${value}</${type}>`;
const vec=(name,v)=>prop('Vector3',name,`<X>${v[0]}</X><Y>${v[1]}</Y><Z>${v[2]}</Z>`);
const col=(name,c)=>prop('Color3',name,`<R>${c[0]/255}</R><G>${c[1]/255}</G><B>${c[2]/255}</B>`);
const bool=(name,v)=>prop('bool',name,v?'true':'false');
const num=(name,v)=>prop('float',name,v);
function cf(p,yaw=0,roll=0){const cy=Math.cos(yaw),sy=Math.sin(yaw),cr=Math.cos(roll),sr=Math.sin(roll);const m=[cy*cr,-cy*sr,sy,sr,cr,0,-sy*cr,sy*sr,cy];return prop('CoordinateFrame','CFrame',`<X>${p[0]}</X><Y>${p[1]}</Y><Z>${p[2]}</Z>`+m.map((x,i)=>`<R${Math.floor(i/3)}${i%3}>${x}</R${Math.floor(i/3)}${i%3}>`).join(''));}
function item(cls,name,props='',children=[]){return {cls,name,props,children,id:'RBX'+(++serial)};}
function xml(o){return `<Item class="${o.cls}" referent="${o.id}"><Properties>${prop('string','Name',esc(o.name))}${o.props}</Properties>${o.children.map(xml).join('')}</Item>`;}
function file(items){return `<?xml version="1.0" encoding="utf-8"?><roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4"><External>null</External><External>nil</External>${items.map(xml).join('')}</roblox>`;}
const folder=(name,children=[])=>item('Folder',name,'',children);
const model=(name,children=[])=>item('Model',name,'',children);
const C={dark:[22,24,40],road:[31,33,49],pale:[181,192,215],cyan:[65,205,255],violet:[156,101,255],pink:[255,70,134],gold:[255,203,94],wood:[95,48,58],grass:[38,75,72]};
function part(name,pos,size,color=C.dark,material=256,options={}){
 const properties=vec('size',size)+cf(pos,options.yaw||0,options.roll||0)+prop('Color3uint8','Color3uint8',4278190080+color[0]*65536+color[1]*256+color[2])+prop('token','Material',material)+bool('Anchored',true)+bool('CanCollide',options.collide!==false)+bool('CanTouch',false)+bool('CanQuery',options.query!==false)+num('Transparency',options.alpha||0)+prop('token','TopSurface',0)+prop('token','BottomSurface',0)+(options.shape!==undefined?prop('token','shape',options.shape):'');
 return item(options.class||'Part',name,properties,options.children||[]);
}
function sign(name,text,pos,size,color=C.cyan,yaw=0){
 const label=item('TextLabel','Lettering',prop('UDim2','Size','<XS>1</XS><XO>0</XO><YS>1</YS><YO>0</YO>')+num('BackgroundTransparency',1)+prop('string','Text',esc(text))+col('TextColor3',color)+bool('TextScaled',true)+prop('token','Font',19));
 const ui=item('SurfaceGui','Sign',prop('token','Face',5)+vec2('CanvasSize',[800,220])+num('PixelsPerStud',35),[label]);
 return part(name,pos,size,[14,17,30],256,{yaw,children:[ui]});
}
function vec2(name,v){return prop('Vector2',name,`<X>${v[0]}</X><Y>${v[1]}</Y>`);}
function add(parent,...children){parent.children.push(...children);}
function ring(parent,pos,r,color,width=0.4){for(let i=0;i<32;i++){let a=i*Math.PI/16;add(parent,part('EnergyInlay',[pos[0]+Math.sin(a)*r,pos[1],pos[2]+Math.cos(a)*r],[width,0.12,r*0.203],color,288,{yaw:a+Math.PI/2,collide:false}));}}
function tree(parent,x,z,flower=false){add(parent,part('Trunk',[x,4,z],[1.6,8,1.6],C.wood,512)); for(const [dx,dy,dz,s] of [[0,10,0,8],[-3,8,1,6],[3,9,-1,6]]) add(parent,part('Canopy',[x+dx,dy,z+dz],[s,s*.7,s],flower?[233,136,194]:[43,99,88],256,{shape:0}));}
function steps(parent,x,z,height=18){for(let i=0;i<12;i++) add(parent,part('RoofAccessStep',[x,i*height/12/2+0.3,z+i*1.5],[7,i*height/12+0.6,1.6],[89,95,116],816));}
function building(parent,dest,x,z,width,depth,height,color,accent,label){
 const b=model(label.replaceAll('\n',' ')); add(parent,b);
 add(b,part('Foundation',[x,0.6,z],[width+1,1.2,depth+1],[66,72,93],816));
 add(b,part('BackFacade',[x,height/2,z+depth/2],[width,height,1.4],color,816));
 for(const side of [-1,1]){
  add(b,part('SideFacade',[x+side*width/2,height/2,z],[1.4,height,depth],color,816));
  add(b,part('FrontPier',[x+side*(width/2-3),height/2,z-depth/2],[6,height,1.4],color,816));
 }
 add(b,part('FrontLintel',[x,height*.7,z-depth/2],[width-12,height*.6,1.4],color,816));
 add(b,part('Roof',[x,height+0.5,z],[width+2,1,depth+2],[40,43,64],816));
 add(b,part('RoofTrim',[x,height+1.1,z-depth/2-1],[width+3,0.25,0.3],accent,288));
 for(let floor=1;floor<height/5;floor++) for(let ix=-width/2+4;ix<width/2-2;ix+=6){
  add(b,part('WindowFrame',[x+ix,floor*5+0.5,z-depth/2-0.76],[4.5,3.4,.16],[11,18,35],256));
  add(b,part('LitWindow',[x+ix,floor*5+0.5,z-depth/2-.88],[3.8,2.7,.12],accent,288,{alpha:.35,collide:false}));
 }
 add(b,sign('Storefront',label,[x,4.8,z-depth/2-1],[width-9,2,.3],accent));
 add(b,part('Awning',[x,3.5,z-depth/2-2.2],[width-8,.4,4],accent,256));
 add(dest,part('Medium_Door',[x,1.8,z-depth/2],[5,3.6,.35],[77,96,123],256));
 add(dest,part('Light_ShopGlass',[x+5,2,z-depth/2],[3,3.4,.25],[95,193,225],1568,{alpha:.45}));
 for(const dx of [-width/2+3,width/2-3]) add(b,part('InteriorCounter',[x+dx,1.5,z-1],[3,3,depth-5],[59,60,80],256));
 if(height<=24) steps(parent,x+width/2+5,z-depth/2,height);
 return b;
}
function baseMap(id,theme){
 const root=model(id), geo=folder('Architecture'), dest=folder('Destructibles'), objs=folder('Objectives'), spawns=folder('SpawnPoints'), pickups=folder('Pickups');
 add(root,geo,dest,objs,spawns,pickups);
 add(geo,part('Ground',[0,-1,0],[300,2,300],theme==='academy'?[46,66,67]:C.road,816));
 for(const v of [-1,1]){add(geo,part('Boundary',[v*150,25,0],[2,50,300],C.dark,256,{alpha:1}));add(geo,part('Boundary',[0,25,v*150],[300,50,2],C.dark,256,{alpha:1}));}
 for(let i=0;i<16;i++){const a=i*Math.PI/8;add(spawns,part('Spawn'+String(i).padStart(2,'0'),[Math.sin(a)*105,.5,Math.cos(a)*105],[3,.2,3],C.cyan,256,{alpha:1,collide:false,query:false}));}
 for(const [i,x,z] of [[1,-72,-48],[2,72,-48],[3,0,86]]){
  add(geo,part('SealDais',[x,.35,z],[13,.7,13],[50,48,79],816)); ring(geo,[x,.78,z],7,C.violet);
  add(objs,part('Seal'+i,[x,2.4,z],[2.5,4,2.5],C.violet,288,{yaw:Math.PI/4}));
  add(geo,sign('SealLabel','SEAL 0'+i,[x,6,z+.8],[8,1.3,.2],C.pale));
 }
 for(const [x,z] of [[-30,-35],[30,35],[-95,65],[95,-65]]) add(pickups,part('EnergyShard',[x,2,z],[1.4,2.4,1.4],C.cyan,288,{yaw:.6}));
 for(const [x,z] of [[-22,28],[22,-28],[-55,72],[55,72],[-98,-20],[98,20]]){
  add(dest,part('Light_Crate',[x,1.7,z],[3.5,3.4,3.5],[108,75,95],816));
  add(geo,part('CrateBand',[x,1.8,z-1.76],[3.4,.2,.07],C.gold,256,{collide:false}));
 }
 return {root,geo,dest,objs};
}
function city(){
 const {root,geo,dest}=baseMap('ShibuyaCity','city');
 for(const x of [-15,15]) add(geo,part('Sidewalk',[x,.2,0],[7,.4,280],[91,100,121],816));
 for(const z of [-15,15]) add(geo,part('Sidewalk',[0,.22,z],[280,.44,7],[91,100,121],816));
 for(let n=-120;n<=120;n+=18){add(geo,part('RoadStripe',[0,.035,n],[.3,.05,8],C.gold,256,{collide:false}));add(geo,part('RoadStripe',[n,.035,0],[8,.05,.3],C.gold,256,{collide:false}));}
 for(const z of [-23,23]) for(let x=-10;x<=10;x+=3) add(geo,part('Crosswalk',[x,.08,z],[1.6,.08,6],[203,211,222],256,{collide:false}));
 const blocks=[[-46,-84,28,30,22,C.cyan,'ASTER\nRAMEN'],[45,-84,32,30,34,C.pink,'NEON\nARCADE'],[-108,-78,25,34,44,C.violet,'CURSE\nSTUDIOS'],[108,-80,26,36,40,C.cyan,'24 / 7'],[-65,42,36,30,20,C.pink,'ECHO\nRECORDS'],[65,42,36,30,22,C.violet,'SORCERER\nSUPPLY'],[-112,95,24,27,40,C.cyan,'TOKYO / 04'],[110,95,25,28,36,C.pink,'NIGHT\nMARKET']];
 for(const [x,z,w,d,h,a,t] of blocks) building(geo,dest,x,z,w,d,h,[47+(x>0?9:0),48,70],a,t);
 for(const x of [-24,24]) for(const z of [-110,-48,50,112]){add(geo,part('LampPost',[x,5,z],[.45,10,.45],[46,51,70],1088));add(geo,part('Lamp',[x,10,z],[2.2,.4,2.2],C.cyan,288));}
 add(geo,part('Skywalk',[-77,21,42],[24,1,7],[65,69,90],816));
 add(geo,sign('DistrictBillboard','SHIBUYA\nAFTER THE RIFT',[0,14,-137],[38,10,1],C.pink));
 ring(geo,[0,.12,0],11,C.cyan);
 return root;
}
function academy(){
 const {root,geo,dest}=baseMap('SorcererAcademy','academy');
 for(const x of [-38,38]) add(geo,part('GardenPath',[x,.15,0],[12,.3,270],[143,135,145],816));
 add(geo,part('Courtyard',[0,.05,0],[100,.1,100],[101,106,126],816)); ring(geo,[0,.2,0],24,C.violet); ring(geo,[0,.22,0],22,C.gold);
 for(const [x,z] of [[-82,-88],[0,-106],[82,-88]]){
  building(geo,dest,x,z,48,32,17,[100,76,89],C.gold,'SORCERER\nACADEMY');
  add(geo,part('PagodaEaves',[x,19,z],[58,2,42],[52,49,79],816));
  add(geo,part('PagodaRoof',[x,21,z],[50,3,34],[72,56,95],816));
  add(geo,part('GoldRidge',[x,23,z],[51,.3,.6],C.gold,1088));
  for(const side of [-1,1]) add(geo,part('RoofWing',[x+side*26,20,z],[5,1,42],[65,52,90],816,{roll:side*.2}));
 }
 for(const x of [-18,18]) add(geo,part('ToriiPillar',[x,7,118],[2.5,14,2.5],[160,53,77],816));
 add(geo,part('ToriiCrossbeam',[0,14,118],[46,2,4],[160,53,77],816));add(geo,part('ToriiCrown',[0,16,118],[51,1.4,5],C.dark,816));
 for(const x of [-125,-103,103,125]) for(const z of [-25,25,70,115]) tree(geo,x,z,(z+25)%70===0);
 for(const [x,z] of [[-70,45],[70,45]]){add(geo,part('Pond',[x,.1,z],[29,.2,24],[55,120,156],1568,{collide:false,alpha:.2}));add(geo,part('Footbridge',[x,1,z],[8,.6,29],C.wood,512));}
 // A destructible partition opens a second route through each classroom.
 for(const x of [-82,0,82]) add(dest,part('Medium_SecretPassage',[x,3,-90],[8,6,.5],[112,83,103],816));
 add(geo,sign('ArenaBanner','FOCUS  •  CONTROL  •  SURVIVE',[0,9,-48],[34,4,.5],C.violet));
 return root;
}
function district(){
 const {root,geo,dest}=baseMap('CursedDistrict','ruins');
 ring(geo,[0,.15,0],31,C.pink); ring(geo,[0,.18,0],34,C.violet);
 add(geo,part('BossArena',[0,.12,0],[65,.24,65],[48,40,67],816));
 for(let i=0;i<12;i++){const a=i*Math.PI/6;add(geo,part('Crack',[Math.sin(a)*60,.2,Math.cos(a)*60],[.65,.12,52],i%2?C.violet:C.pink,288,{yaw:a+.2,collide:false}));}
 for(const [x,z,h] of [[-90,-92,27],[0,-114,20],[90,-92,32],[-106,60,29],[106,60,23]]){
  const b=building(geo,dest,x,z,34,30,h,[55,47,67],C.pink,'QUARANTINE');
  add(dest,part('Heavy_Facade',[x-12,7,z-18],[6,14,2],[76,63,85],816));
  add(dest,part('Heavy_Column',[x+10,5,z-20],[3,10,3],[88,77,96],816));
  add(b,part('BrokenBeam',[x,17,z-10],[22,2,2],[91,73,93],1088,{roll:.25}));
 }
 for(const x of [-44,44]){add(dest,part('Heavy_Platform',[x,6,40],[22,1.5,18],[72,59,89],816));steps(geo,x,12,6);}
 for(const x of [-18,18]) add(geo,part('Monolith',[x,7,-38],[4,14,4],C.dark,816,{roll:x*.005}));
 add(geo,sign('Warning','CURSED DISTRICT\nTHE SEAL IS BREAKING',[0,15,-42],[35,6,1],C.pink));
 return root;
}
function lobby(){
 const root=model('Lobby');
 add(root,part('LobbyIsland',[0,-2,360],[164,4,122],[25,29,47],816));
 add(root,part('LobbyFloor',[0,.2,360],[156,.4,114],[50,55,76],816));
 for(const x of [-77,77]) add(root,part('Rail',[x,3,360],[1,6,114],[83,94,122],1568,{alpha:.5}));
 for(const z of [304,416]) add(root,part('Rail',[0,3,z],[156,6,1],[83,94,122],1568,{alpha:.5}));
 ring(root,[0,.5,360],19,C.violet);ring(root,[0,.5,360],21,C.cyan);
 for(const x of [-48,48]){add(root,part('PavilionColumn',[x,9,325],[3,18,3],C.dark,816));add(root,part('LightColumn',[x,9,323.4],[.4,16,.1],x<0?C.cyan:C.pink,288));}
 add(root,part('PavilionBeam',[0,19,325],[108,3,8],[36,33,59],816));
 add(root,sign('Title','JUJUTSU\nCURSED SURVIVAL',[0,12,326],[76,12,1],C.pale));
 add(root,sign('Subtitle','ENTER THE RIFT  /  MASTER YOUR CURSE',[0,4,326],[64,3,.7],C.violet));
 for(const [x,label,color] of [[-50,'AZURE\nSPATIAL GUARDIAN',C.cyan],[50,'CRIMSON\nRIFT SOVEREIGN',C.pink]]){
  add(root,part('HeroPlinth',[x,1.5,360],[17,3,17],[35,35,58],816));ring(root,[x,3.1,360],7,color);
  add(root,part('EnergySculpture',[x,7,360],[4,7,4],color,288,{yaw:Math.PI/4,alpha:.25}));
  add(root,sign('HeroLabel',label,[x,4,370],[23,4,.5],color));
 }
 for(const x of [-58,58]){tree(root,x,397,true);add(root,part('Bench',[x,1.6,385],[16,1,4],C.wood,512));}
 add(root,sign('Controls','WASD  MOVE   /   Q E R F T  TECHNIQUES\nSHIFT  SPRINT   /   G  DOMAIN',[0,5,408],[60,5,.6],C.cyan,Math.PI));
 const spawn=part('LobbySpawn',[0,1,375],[8,1,8],C.violet,288,{class:'SpawnLocation',alpha:.5});spawn.props+=bool('Neutral',true)+num('Duration',0);add(root,spawn);
 return root;
}
// These drafts are references only. Import selected changes deliberately after review.
const maps=[city(),academy(),district()],lob=lobby();
for(const model of [...maps,lob]) fs.writeFileSync(path.join(output,model.name+'.rbxmx'),file([model]),{flag:'wx'});
console.log('Draft models written to '+path.relative(ROOT,output)+'. Authored assets and default.project.json were not modified.');
