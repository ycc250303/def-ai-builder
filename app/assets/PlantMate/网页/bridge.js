/* Plant Mate integrated app hub. Garden V12 source is an unmodified embedded document. */
(function(){
'use strict';
const frames={garden:document.getElementById('pm-garden'),social:document.getElementById('pm-social'),me:document.getElementById('pm-me')};
const loaded={garden:false,social:false,me:false};
let current='garden',live=null,lastKey='',mapImage='',lastMapAt=0,previousStats=null;
let journal=[],saves=[],likes=[],following=[],visitMode='public',bio='A little green world, one day at a time 🌱';
const typed={FEED:'Care',CLEAN:'Care',PLAY:'Care',EXPLORE:'Explore',REST:'Care'};
const actName={FEED:'Feeding',CLEAN:'Cleaning',PLAY:'Playing',EXPLORE:'Exploring',REST:'Resting'};
const canvas=document.createElement('canvas');canvas.width=675;canvas.height=1292;
function dFrame(){return frames.garden.contentDocument;}
function read(){
  if(!loaded.garden)return null;
  try{
    const d=dFrame();const f=frames.garden.contentWindow;
    if(!f.plantMatePrototype)return null;
    const data=f.plantMatePrototype.getState();
    let owner=(d.getElementById('farmTitle')?.textContent||"hi's Garden").replace(/['’]s\s+Garden\s*$/i,'').trim();
    return {owner,petName:'Eggie',level:data.level,xp:data.xp,food:data.food,mood:data.mood,energy:data.energy,clean:data.clean,behavior:data.behavior, event:d.getElementById('eventText')?.textContent?.trim()||'',
      countdown:d.getElementById('countdown')?.textContent||'',visitMode,bio,connected:true,
      tuantuan:d.getElementById('plantSlot')?.src||'',eggie:d.getElementById('eggSlot')?.src||'',baybi:d.querySelector('.evo-picture img[src*="baybi"]')?.src||window.PlantMateExtraAssets?.baybi||'',
      saves:saves.slice(),likes:likes.slice(),following:following.slice(),journal:journal.slice(),map:mapImage};
  }catch(err){console.error('Garden V12 sync read:',err);return null;}
}
function captureMap(){
  if(!loaded.garden)return;
  try{
    const d=dFrame(),w=frames.garden.contentWindow,world=d.getElementById('world');
    if(!world)return;
    const ctx=canvas.getContext('2d');ctx.imageSmoothingEnabled=false;ctx.clearRect(0,0,675,1292);
    const bg=world.querySelector('.map-base');ctx.fillStyle=w.getComputedStyle(bg).backgroundColor||'#348e8e';ctx.fillRect(0,0,675,1292);
    for(const el of world.querySelectorAll('.map-ground')){
      const s=w.getComputedStyle(el);ctx.fillStyle=s.backgroundColor;
      ctx.fillRect(parseFloat(el.style.left)||0,parseFloat(el.style.top)||0,parseFloat(el.style.width)||0,parseFloat(el.style.height)||0);
    }
    const all=[...world.querySelectorAll('img.map-sprite')].filter(el=>el.complete&&el.naturalWidth>0&&el.id!=='eggSlot'&&el.id!=='plantSlot');
    all.sort((a,b)=>(Number(a.style.zIndex||3)-Number(b.style.zIndex||3)));
    for(const el of all){try{ctx.drawImage(el,Math.round(parseFloat(el.style.left)||0),Math.round(parseFloat(el.style.top)||0),el.offsetWidth,el.offsetHeight)}catch(_){}}
    mapImage=canvas.toDataURL('image/png');lastMapAt=Date.now();
  }catch(err){console.warn('Map snapshot:',err);}
}
function listenNav(name){
 const d=frames[name].contentDocument;
 if(!d)return;
 d.addEventListener('click',event=>{
   const button=name==='garden'?event.target.closest('#nav button[data-tab]'):event.target.closest('#bottomnav button');
   if(!button)return;
   const text=(name==='garden'?button.dataset.tab:button.textContent||'').trim().toLowerCase();
   let target=text.includes('garden')?'garden':text.includes('social')?'social':text==='me'?'me':null;
   if(!target)return;
   event.preventDefault();event.stopPropagation();event.stopImmediatePropagation();show(target);
 },true);
}
function show(target,opts={}){
 if(!frames[target])return;
 current=target;
 for(const [name,frame] of Object.entries(frames)){
   const active=name===target;frame.style.opacity=active?'1':'0';frame.style.pointerEvents=active?'auto':'none';frame.style.zIndex=active?'5':'1';frame.setAttribute('aria-hidden',active?'false':'true');
 }
 if(target!=='garden'&&(!mapImage||Date.now()-lastMapAt>1600))captureMap();
 deliver();
 try{
  if(target==='social'&&frames.social.contentWindow.PlantMateSocialOpen)frames.social.contentWindow.PlantMateSocialOpen(opts);
  if(target==='me'&&frames.me.contentWindow.PlantMateMeOpen)frames.me.contentWindow.PlantMateMeOpen(opts);
 }catch(err){console.warn('Navigation',err)}
}
function storeAction(n){
 if(!n||!previousStats)return;
 const stats=['food','mood','energy','clean','xp','level'];
 let changed=stats.some(k=>n[k]!==previousStats[k]);
 if(!changed)return;
 const t=new Date();
 const fmt=t.toLocaleTimeString('en-GB',{hour:'2-digit',minute:'2-digit'});
 const type=typed[n.behavior]||'Care';
 let diff=stats.filter(k=>n[k]!==previousStats[k]).map(k=>{
   let a=n[k]-previousStats[k];return `${k.toUpperCase()} ${a>0?'+':''}${a}`;
 }).join(' · ');
 journal.unshift({type,title:`${actName[n.behavior]||n.behavior} completed`,date:`Today · ${fmt}`,detail:`${n.event} · ${diff}`});
 if(n.level>previousStats.level)journal.unshift({type:'Growth',title:`Eggie reached Lv.${n.level}`,date:`Today · ${fmt}`,detail:'The level increase comes from Garden V12 XP calculations.'});
 journal=journal.slice(0,80);
}
function deliver(){
 const n=live||read();if(!n)return;
 const shared={...n,journal:journal.slice(),saves:saves.slice(),likes:likes.slice(),following:following.slice(),visitMode,map:mapImage};
 for(const x of ['social','me'])if(loaded[x]){
   try{let fn=frames[x].contentWindow[x==='social'?'PlantMateSocialSync':'PlantMateMeSync'];if(fn)fn(shared)}catch(err){console.warn(x+' sync',err)}
 }
}
function poll(){
 const n=read();if(!n)return;
 if(previousStats)storeAction(n);
 previousStats=n;
 live={...n};
 if(!mapImage||(current!=='garden'&&Date.now()-lastMapAt>2200))captureMap();
 const key=[n.owner,n.level,n.xp,n.food,n.mood,n.energy,n.clean,n.behavior,n.event,visitMode,saves.join(','),journal.length].join('|');
 if(key!==lastKey){lastKey=key;deliver();}
 else if(current!=='garden'&&Date.now()-lastMapAt<700)deliver();
}
function renameOwner(name){
 if(!loaded.garden||!name)return;
 try{
  const d=dFrame();d.getElementById('renameButton').click();
  const input=d.getElementById('gardenInput');if(!input)return;
  input.value=name;
  const btn=d.querySelector('#modalActions button.primary');if(btn)btn.click();
  poll();
 }catch(err){console.warn('Rename from native V12:',err)}
}
function updateSocial(d){if(d.saves)saves=d.saves;if(d.likes)likes=d.likes;if(d.following)following=d.following;deliver();}
function setVisitMode(mode){visitMode=mode;deliver();}
window.PlantMateHub={show,read,renameOwner,setVisitMode,updateSocial,getSnapshot:()=>({...live,map:mapImage,journal:journal.slice(),saves:saves.slice()}),
 debugAdvance:()=>{try{frames.garden.contentWindow.plantMatePrototype.advance();poll()}catch(err){console.warn(err)}}};
function initializeFrame(name){
 if(loaded[name])return;
 loaded[name]=true;listenNav(name);
 if(name==='garden'){captureMap();poll();}
 deliver();
}
for(const [name,frame] of Object.entries(frames))frame.addEventListener('load',()=>initializeFrame(name));
// Standalone: HTML source strings are stored losslessly in encoded script payloads.
if(window.__pmEmbeddedPages){
  const decode=(base64)=>{const binary=atob(base64),bytes=new Uint8Array(binary.length);for(let i=0;i<binary.length;i++)bytes[i]=binary.charCodeAt(i);return new TextDecoder('utf-8').decode(bytes);};
  for(const name of ['garden','social','me'])frames[name].srcdoc=decode(window.__pmEmbeddedPages[name]);
}
setInterval(poll,650);
})();
