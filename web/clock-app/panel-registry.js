'use strict';

(() => {
  const theme=document.createElement('link');
  theme.rel='stylesheet';
  theme.href='premium-theme.css';
  theme.dataset.einkTheme='premium-v2-clock-card';
  document.head.append(theme);

  const DEFAULT_PANEL_ID='hink213-bw-250x122';
  const CLASSIC_VALUE='clock-classic';
  const CLASSIC_STORAGE_KEY='eink-premium-web-profile';
  let savedCanvasPreview=null;

  const PANEL_REGISTRY=Object.freeze({
    [DEFAULT_PANEL_ID]:Object.freeze({
      id:'hink213-bw-250x122',
      logicalWidth:250,
      logicalHeight:122,
      ramWidth:122,
      ramHeight:250,
      stride:16,
      planeCount:1,
      payloadBytes:4000,
      rotation:3,
      bitOrder:'msb-first',
      whiteBit:1
    })
  });

  const ACTIVE_PANEL=PANEL_REGISTRY[DEFAULT_PANEL_ID];

  window.EINK_PANEL_REGISTRY=PANEL_REGISTRY;
  window.EINK_DEFAULT_PANEL_ID=DEFAULT_PANEL_ID;
  window.EINK_ACTIVE_PANEL=ACTIVE_PANEL;

  const pad=value=>String(value).padStart(2,'0');

  function parseDeviceClock(){
    const ble=document.getElementById('ble');
    const local=document.getElementById('d2LocalTime');
    if(!ble||!local)return null;

    const bleText=(ble.textContent||'').trim().toLowerCase();
    if(!bleText.includes('connected')||bleText.includes('disconnected'))return null;

    const text=(local.textContent||'').trim();
    const time=text.match(/(?:^|\s)([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?:\s|$)/);
    if(!time)return null;

    const date=new Date();
    date.setHours(Number(time[1]),Number(time[2]),Number(time[3]||0),0);
    return date;
  }

  function currentClockDate(){
    return parseDeviceClock()||new Date();
  }

  function addTicks(face){
    for(let index=0;index<12;index++){
      const tick=document.createElement('span');
      tick.className=`productAnalogTick${index%3===0?' major':''}`;
      tick.style.transform=`rotate(${index*30}deg)`;
      face.append(tick);
    }
  }

  function drawClassicCanvas(){
    const canvas=document.getElementById('canvas');
    const ctx=canvas?.getContext?.('2d');
    if(!canvas||!ctx||!canvas.width||!canvas.height)return;

    if(!savedCanvasPreview){
      try{
        savedCanvasPreview={
          width:canvas.width,
          height:canvas.height,
          image:ctx.getImageData(0,0,canvas.width,canvas.height)
        };
      }catch{}
    }

    const now=currentClockDate();
    const hours=now.getHours();
    const minutes=now.getMinutes();
    const seconds=now.getSeconds();
    const weekdays=['CN','T2','T3','T4','T5','T6','T7'];
    const dateLabel=`${weekdays[now.getDay()]}  ${pad(now.getDate())}/${pad(now.getMonth()+1)}/${now.getFullYear()}`;

    ctx.save();
    ctx.setTransform(canvas.width/250,0,0,canvas.height/122,0,0);
    ctx.fillStyle='#fff';
    ctx.fillRect(0,0,250,122);
    ctx.fillStyle='#000';
    ctx.strokeStyle='#000';
    ctx.lineCap='round';
    ctx.lineJoin='round';

    ctx.font='700 9px ui-monospace, SFMono-Regular, Consolas, monospace';
    ctx.fillText('CLOCK CLASSIC',12,14);
    ctx.font='600 8px ui-monospace, SFMono-Regular, Consolas, monospace';
    ctx.fillText(dateLabel,12,28);

    ctx.font='800 48px ui-monospace, SFMono-Regular, Consolas, monospace';
    ctx.fillText(`${pad(hours)}:${pad(minutes)}`,9,78);

    ctx.font='600 8px ui-monospace, SFMono-Regular, Consolas, monospace';
    ctx.fillText(parseDeviceClock()?'DEVICE TIME':'WEB PREVIEW',13,108);

    const cx=201;
    const cy=61;
    const radius=41;
    ctx.lineWidth=2;
    ctx.beginPath();
    ctx.arc(cx,cy,radius,0,Math.PI*2);
    ctx.stroke();

    for(let index=0;index<12;index++){
      const angle=(index*Math.PI/6)-Math.PI/2;
      const inner=radius-(index%3===0?8:5);
      ctx.lineWidth=index%3===0?2:1;
      ctx.beginPath();
      ctx.moveTo(cx+Math.cos(angle)*inner,cy+Math.sin(angle)*inner);
      ctx.lineTo(cx+Math.cos(angle)*(radius-2),cy+Math.sin(angle)*(radius-2));
      ctx.stroke();
    }

    const hourAngle=(((hours%12)+(minutes/60))*Math.PI/6)-Math.PI/2;
    const minuteAngle=((minutes+(seconds/60))*Math.PI/30)-Math.PI/2;
    const secondAngle=(seconds*Math.PI/30)-Math.PI/2;

    ctx.lineWidth=4;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(hourAngle)*21,cy+Math.sin(hourAngle)*21);
    ctx.stroke();

    ctx.lineWidth=3;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(minuteAngle)*31,cy+Math.sin(minuteAngle)*31);
    ctx.stroke();

    ctx.lineWidth=1;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(secondAngle)*34,cy+Math.sin(secondAngle)*34);
    ctx.stroke();

    ctx.beginPath();
    ctx.arc(cx,cy,3,0,Math.PI*2);
    ctx.fill();
    ctx.restore();
  }

  function restoreCanvasPreview(){
    const canvas=document.getElementById('canvas');
    const ctx=canvas?.getContext?.('2d');
    if(!canvas||!ctx||!savedCanvasPreview)return;

    if(canvas.width===savedCanvasPreview.width&&canvas.height===savedCanvasPreview.height){
      try{ctx.putImageData(savedCanvasPreview.image,0,0);}catch{}
    }
    savedCanvasPreview=null;
  }

  function createClockCard(){
    if(document.querySelector('.productProfileClock'))return null;

    const card=document.createElement('div');
    card.className='productProfileClock';
    card.dataset.einkPremiumClock='v2-profile';
    card.innerHTML=`
      <div class="productClockCopy">
        <div class="productClockEyebrow">Clock Classic</div>
        <div class="productClockTime" aria-live="polite">--:--</div>
        <div class="productClockMeta">
          <strong class="productClockDate">--</strong>
          <span class="productClockSource">Giờ trình duyệt</span>
        </div>
      </div>
      <div class="productAnalogClock" aria-hidden="true">
        <span class="productAnalogHand productAnalogHour"></span>
        <span class="productAnalogHand productAnalogMinute"></span>
        <span class="productAnalogHand productAnalogSecond"></span>
        <span class="productAnalogCenter"></span>
      </div>`;

    addTicks(card.querySelector('.productAnalogClock'));
    return card;
  }

  function updateClockCard(card){
    if(!card?.isConnected)return;
    const deviceDate=parseDeviceClock();
    const now=deviceDate||new Date();
    const hours=now.getHours();
    const minutes=now.getMinutes();
    const seconds=now.getSeconds();

    card.querySelector('.productClockTime').textContent=`${pad(hours)}:${pad(minutes)}`;
    card.querySelector('.productClockDate').textContent=new Intl.DateTimeFormat('vi-VN',{
      weekday:'long',day:'2-digit',month:'2-digit',year:'numeric'
    }).format(now);

    const source=card.querySelector('.productClockSource');
    source.textContent=deviceDate?'Giờ đang đọc từ thiết bị':'Giờ hiện tại trên trình duyệt';
    source.classList.toggle('is-device',!!deviceDate);

    card.querySelector('.productAnalogHour').style.transform=`rotate(${(hours%12)*30+minutes*.5}deg)`;
    card.querySelector('.productAnalogMinute').style.transform=`rotate(${minutes*6+seconds*.1}deg)`;
    card.querySelector('.productAnalogSecond').style.transform=`rotate(${seconds*6}deg)`;
  }

  function syncClassicApply(active){
    const apply=document.getElementById('profileApply');
    if(!apply)return;

    if(active){
      if(!apply.dataset.classicOriginalLabel){
        apply.dataset.classicOriginalLabel=apply.textContent||'Áp dụng lên màn';
      }
      apply.dataset.classicPreview='true';
      apply.textContent='Preview web — chưa áp dụng';
      apply.disabled=true;
      apply.setAttribute('aria-disabled','true');
    }else if(apply.dataset.classicPreview==='true'){
      apply.textContent=apply.dataset.classicOriginalLabel||'Áp dụng lên màn';
      apply.disabled=false;
      apply.removeAttribute('aria-disabled');
      delete apply.dataset.classicPreview;
    }
  }

  function setClassicUi(active){
    const profile=document.querySelector('.productModeV2Profiles');
    const select=document.getElementById('productLayoutSelect');
    const card=document.querySelector('.productProfileClock');
    const classicButton=document.querySelector('[data-eink-classic-profile]');
    const deviceButtons=[...document.querySelectorAll('#productPresetRow button[data-layout-profile]')]
      .filter(button=>button!==classicButton);

    if(!profile||!select||!card)return;

    profile.dataset.webProfile=active?CLASSIC_VALUE:'device';
    card.hidden=!active;
    classicButton?.classList.toggle('selected',active);
    deviceButtons.forEach(button=>button.classList.toggle('selected',!active&&button.dataset.layoutProfile===select.value));
    syncClassicApply(active);

    if(active){
      select.value=CLASSIC_VALUE;
      drawClassicCanvas();
      try{localStorage.setItem(CLASSIC_STORAGE_KEY,CLASSIC_VALUE);}catch{}
    }else{
      restoreCanvasPreview();
      try{localStorage.removeItem(CLASSIC_STORAGE_KEY);}catch{}
    }
  }

  function ensureClassicChoice(){
    const profile=document.querySelector('.productModeV2Profiles');
    const select=document.getElementById('productLayoutSelect');
    const row=document.getElementById('productPresetRow');
    if(!profile||!select||!row)return false;

    if(!select.querySelector(`option[value="${CLASSIC_VALUE}"]`)){
      const option=document.createElement('option');
      option.value=CLASSIC_VALUE;
      option.textContent='Clock Classic — Số + Kim';
      select.append(option);
    }

    let classicButton=row.querySelector('[data-eink-classic-profile]');
    if(!classicButton){
      classicButton=document.createElement('button');
      classicButton.type='button';
      classicButton.dataset.einkClassicProfile='true';
      classicButton.dataset.layoutProfile=CLASSIC_VALUE;
      classicButton.textContent='Clock Classic';
      row.append(classicButton);
      row.style.setProperty('grid-template-columns','repeat(2,minmax(0,1fr))','important');
    }

    if(!profile.querySelector('.productClassicNote')){
      const note=document.createElement('p');
      note.className='productClassicNote';
      note.textContent='Clock Classic đang đổi preview web 250×122. Chưa gửi profile mới xuống firmware ở bước UI này.';
      note.hidden=true;
      row.insertAdjacentElement('afterend',note);
    }

    return true;
  }

  function renderClassicState(active){
    setClassicUi(active);
    const note=document.querySelector('.productClassicNote');
    if(note)note.hidden=!active;
    const status=document.getElementById('profileStatus');
    if(active&&status){
      status.textContent='Đang xem Clock Classic trên preview web 250×122. Profile e-ink trên thiết bị chưa thay đổi.';
    }
  }

  function mountPremiumClock(){
    const profile=document.querySelector('.productModeV2Profiles');
    const intro=profile?.querySelector('.productProfileIntro');
    if(!profile||!intro)return false;

    let card=document.querySelector('.productProfileClock');
    if(!card){
      card=createClockCard();
      if(!card)return true;
      intro.insertAdjacentElement('afterend',card);
    }

    if(!ensureClassicChoice())return false;

    let restoreClassic=false;
    try{restoreClassic=localStorage.getItem(CLASSIC_STORAGE_KEY)===CLASSIC_VALUE;}catch{}
    renderClassicState(restoreClassic);
    updateClockCard(card);

    if(!window.__einkPremiumClockTimer){
      window.__einkPremiumClockTimer=setInterval(()=>{
        const mounted=document.querySelector('.productProfileClock');
        if(mounted)updateClockCard(mounted);
        const profileCard=document.querySelector('.productModeV2Profiles');
        if(profileCard?.dataset.webProfile===CLASSIC_VALUE){
          drawClassicCanvas();
          syncClassicApply(true);
        }
      },1000);
    }
    return true;
  }

  document.addEventListener('change',event=>{
    if(event.target?.id!=='productLayoutSelect')return;

    if(event.target.value===CLASSIC_VALUE){
      event.preventDefault();
      event.stopImmediatePropagation();
      renderClassicState(true);
      return;
    }

    renderClassicState(false);
  },true);

  document.addEventListener('click',event=>{
    const classicButton=event.target.closest?.('[data-eink-classic-profile]');
    if(classicButton){
      event.preventDefault();
      event.stopImmediatePropagation();
      renderClassicState(true);
      return;
    }

    const deviceButton=event.target.closest?.('#productPresetRow button[data-layout-profile]');
    if(deviceButton){
      renderClassicState(false);
      return;
    }

    const apply=event.target.closest?.('#profileApply');
    const select=document.getElementById('productLayoutSelect');
    if(apply&&select?.value===CLASSIC_VALUE){
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  },true);

  function installPremiumClock(){
    if(mountPremiumClock())return;

    const observer=new MutationObserver(()=>{
      if(mountPremiumClock())observer.disconnect();
    });
    observer.observe(document.documentElement,{childList:true,subtree:true});
    setTimeout(()=>observer.disconnect(),15000);
  }

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',installPremiumClock,{once:true});
  }else{
    installPremiumClock();
  }
})();
