'use strict';

(() => {
  const theme=document.createElement('link');
  theme.rel='stylesheet';
  theme.href='premium-theme.css';
  theme.dataset.einkTheme='premium-v2-clock-card';
  document.head.append(theme);

  const DEFAULT_PANEL_ID='hink213-bw-250x122';

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
    if(!ble||!local||!/connected/i.test(ble.textContent||''))return null;

    const text=(local.textContent||'').trim();
    const time=text.match(/(?:^|\s)([01]?\d|2[0-3]):([0-5]\d)(?::([0-5]\d))?(?:\s|$)/);
    if(!time)return null;

    const date=new Date();
    date.setHours(Number(time[1]),Number(time[2]),Number(time[3]||0),0);
    return date;
  }

  function addTicks(face){
    for(let index=0;index<12;index++){
      const tick=document.createElement('span');
      tick.className=`productAnalogTick${index%3===0?' major':''}`;
      tick.style.transform=`rotate(${index*30}deg)`;
      face.append(tick);
    }
  }

  function createClockCard(){
    if(document.querySelector('.productModeV2Clock'))return null;

    const card=document.createElement('section');
    card.className='card productModeV2Clock';
    card.dataset.einkPremiumClock='v2';
    card.innerHTML=`
      <div class="productClockCopy">
        <div class="productClockEyebrow">Current clock</div>
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

  function mountPremiumClock(){
    const main=document.querySelector('main.productModeV2');
    const header=document.querySelector('.productModeV2Header');
    if(!main||!header)return false;

    let card=document.querySelector('.productModeV2Clock');
    if(!card){
      card=createClockCard();
      if(!card)return true;
      header.insertAdjacentElement('afterend',card);
    }

    updateClockCard(card);
    if(!window.__einkPremiumClockTimer){
      window.__einkPremiumClockTimer=setInterval(()=>{
        const mounted=document.querySelector('.productModeV2Clock');
        if(mounted)updateClockCard(mounted);
      },1000);
    }
    return true;
  }

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
