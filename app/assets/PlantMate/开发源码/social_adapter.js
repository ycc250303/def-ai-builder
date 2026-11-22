/* Integrated Social adapter. Garden V12 stays untouched and supplies the authoritative state. */
(function(){
  'use strict';
  const originalSave=save, originalFollow=toggleFollow;
  const localUser=PEOPLE.find(x=>x.id==='lily');
  let syncSignature=''; let activeMap='';
  function sendSocial(){try{window.parent.PlantMateHub.updateSocial({saves:[...state.saves],likes:[...state.likes],following:PEOPLE.filter(x=>x.following).map(x=>x.id)});}catch(_){}}
  save=function(id){originalSave(id);sendSocial();};
  toggleFollow=function(id){originalFollow(id);sendSocial();};
  // Reuse V12 layered map; remove overlay decorations because the layer-export already includes them.
  // Each scene still renders exactly ONE Tuantuan and ONE virtual pet.
  scene=function(uid,kind='feed',crop=61){
    const u=user(uid);
    const sceneHeight=kind==='visit'?660:kind==='post'?290:kind==='home'?540:kind==='search'?112:182;
    const mapCrop=kind==='visit'||kind==='home'?0:kind==='post'?-154:kind==='search'?-95:-115;
    let inner=`<img class="map-img" src="${IMAGES.map}" style="top:${mapCrop}px" alt="Garden V12 layered-map rendering"/>`;
    inner+=`<img class="sprite plant" src="${IMAGES.tuantuan}" alt="Tuantuan · autonomous virtual plant"/><img class="sprite pet" src="${IMAGES[u.pet]}" alt="${esc(u.petName)} · one virtual pet"/>`;
    const clickable=['feed','post'].includes(kind);
    return `<div class="garden-scene ${kind}" ${clickable?`role="button" tabindex="0" onclick="openPost('${postForUser(uid).id}')" onkeydown="if(event.key==='Enter')openPost('${postForUser(uid).id}')"`:''} aria-label="Garden V12 environment with one Tuantuan, one ${esc(u.petName)}; blue puppy is decorative">${inner}</div>`;
  };
  // Site V12 is authoritative for the owner's garden, XP and current level.
  window.PlantMateSocialSync=function(data){
    if(!data)return;
    IMAGES.tuantuan=data.tuantuan||IMAGES.tuantuan;
    IMAGES.egg=data.eggie||IMAGES.egg;
    if(data.map){IMAGES.map=data.map;activeMap=data.map;}
    localUser.name=data.owner;
    localUser.pet='egg';localUser.avatar='egg';localUser.petName=data.petName||'Eggie';
    localUser.level=data.level;localUser.bio=data.bio||'Tuantuan and Eggie · Plant Mate';
    localUser.open=data.visitMode!=='closed';
    // This key excludes countdown and map-image changes; avoid disturbing search/caption input focus.
    const key=[data.owner,data.petName,data.level,data.visitMode].join('|');
    if(syncSignature!==key){syncSignature=key;render(false);}
    else if(data.map){document.querySelectorAll('.garden-scene .map-img').forEach(el=>{if(el.src!==activeMap)el.src=activeMap;});}
  };
  window.PlantMateSocialOpen=function(opts={}){
    if(opts.page==='post'){openPost(opts.post||'p1');return;}
    if(opts.page==='visit'){openGarden(opts.owner||'lily');return;}
    if(opts.page==='notifications'){go('notifications');return;}
    if(opts.page==='saved'){go('feed');return;}
    if(opts.page==='following'){state.tab='following';go('feed');return;}
    if(opts.page==='recommended'){state.tab='recommended';go('feed');return;}
    if(opts.page==='search'){go('search');return;}
    go('feed');
  };
  // Current user's public garden uses one owner; demo visitors are presentation users with the same V12 map system.
  // Leave the approved V4 comments, saved posts, recommendations, searching, and notifications UI intact.
  try{sendSocial();}catch(_){ }
})();
