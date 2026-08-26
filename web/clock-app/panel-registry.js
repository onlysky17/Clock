'use strict';

(() => {
  const theme=document.createElement('link');
  theme.rel='stylesheet';
  theme.href='premium-theme.css';
  theme.dataset.einkTheme='premium-v2-clock-card';
  document.head.append(theme);

  if(!document.querySelector('script[data-eink-week-calendar]')){
    const weekScript=document.createElement('script');
    weekScript.src='weekly-calendar-preview.js';
    weekScript.dataset.einkWeekCalendar='v1';
    document.head.append(weekScript);
  }

  const DEFAULT_PANEL_ID='hink213-bw-250x122';
  const CLASSIC_VALUE='clock-classic';
  const CLASSIC_STORAGE_KEY='eink-premium-web-profile';
  const CLASSIC_CADENCES=[1,5,10,15,30];
  let classicCadence=5;
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

  function ensureClassicCadenceStyles(){
    if(document.getElementById('einkClassicCadenceStyle'))return;
    const style=document.createElement('style');
    style.id='einkClassicCadenceStyle';
    style.textContent=`
      .productClockCadence{grid-column:1/-1;display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:5px;margin-top:2px;padding-top:10px;border-top:1px solid rgba(145,176,205,.12)}
      .productProfileClock .productClockCopy,.productProfileClock .productAnalogClock{display:none!important}
      .productProfileClock{display:block!important;margin:0!important;padding:0!important;border:0!important;background:transparent!important;box-shadow:none!important}
      .productProfileClock[hidden]{display:none!important}
      .productClockCadence button{min-width:0!important;min-height:32px!important;padding:6px 4px!important;border-radius:9px!important;font-size:.72rem!important;font-weight:800!important;color:#93a9be!important;background:rgba(5,13,23,.5)!important}
      .productClockCadence button.selected{border-color:rgba(91,220,255,.42)!important;background:linear-gradient(135deg,rgba(91,220,255,.95),rgba(48,183,230,.95))!important;color:#03121b!important;box-shadow:0 5px 14px rgba(33,191,242,.16)}
      .productModeV2Workspace{grid-column:1/-1;display:grid;grid-template-columns:minmax(0,1.25fr) minmax(330px,.75fr);gap:18px;align-items:start;min-width:0}
      .productModeV2WorkspaceColumn{display:flex;flex-direction:column;gap:18px;min-width:0}
      .productModeV2Workspace .card{margin:0!important;grid-column:auto!important;grid-row:auto!important;width:100%}
      .productModeV2OwnerControls{align-self:stretch;min-width:0}
      .productModeV2OwnerControls .preferencePanel{margin:0;padding:0;border-top:0}
      .productModeV2OwnerControls .preferencePanel h3{margin:0 0 12px;font-size:1rem;color:#f4f9ff}
      .productModeV2OwnerControls .preferenceRow{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px;margin-bottom:9px}
      .productModeV2OwnerControls #hourModeRow{grid-template-columns:repeat(2,minmax(0,1fr))}
      .productModeV2OwnerControls button{min-width:0!important;width:100%}
      .productModeV2OwnerControls .preferenceHint{margin:6px 0 10px;font-size:.8rem;line-height:1.45}
      .productModeV2Workspace .productModeV2Preview,.productModeV2Workspace .productModeV2Actions,.productModeV2Workspace .productModeV2Profiles{align-self:stretch}
      .productModeV2DeviceAdvanced{margin-top:14px!important}
      .productModeV2Preview canvas.classicDeviceCanvasHidden{display:none!important}
      .productModeV2Preview canvas.classicWebPreview{display:block!important;image-rendering:auto!important;filter:none!important;background:#fff!important}
      @media(max-width:900px){.productModeV2Workspace{grid-template-columns:minmax(0,1.1fr) minmax(300px,.9fr);gap:14px}.productModeV2WorkspaceColumn{gap:14px}}
      @media(max-width:760px){.productModeV2Workspace{grid-template-columns:minmax(0,1fr);gap:14px}.productModeV2WorkspaceColumn{gap:14px}.productModeV2OwnerControls .preferenceRow{gap:6px}}
      @media(max-width:430px){.productClockCadence{gap:4px}.productClockCadence button{min-height:30px!important;padding:5px 2px!important;font-size:.68rem!important}.productModeV2OwnerControls .preferenceRow{gap:5px}}
    `;
    document.head.append(style);
  }

  function ensureOwnerPriorityLayout(){
    const root=document.querySelector('main.productModeV2');
    const header=document.querySelector('.productModeV2Header');
    const previewCard=document.querySelector('.productModeV2Preview');
    const actionsCard=document.querySelector('.productModeV2Actions');
    const profileCard=document.querySelector('.productModeV2Profiles');
    const preferencePanel=document.querySelector('.preferencePanel');
    const advanced=document.querySelector('.productModeV2Advanced');
    const advancedBody=advanced?.querySelector('.advancedBody');
    const deviceCard=document.querySelector('.productModeV2Device');
    if(!root)return;

    let controlsCard=document.querySelector('.productModeV2OwnerControls');
    if(!controlsCard&&preferencePanel){
      controlsCard=document.createElement('section');
      controlsCard.className='card productModeV2OwnerControls';
    }
    if(controlsCard)controlsCard.dataset.appView='clock';
    if(controlsCard&&preferencePanel&&preferencePanel.parentElement!==controlsCard){
      preferencePanel.classList.add('productOwnerPreferences');
      controlsCard.append(preferencePanel);
    }

    let workspace=document.querySelector('.productModeV2Workspace');
    if(!workspace){
      workspace=document.createElement('div');
      workspace.className='productModeV2Workspace';
      workspace.innerHTML='<div class="productModeV2WorkspaceColumn productModeV2WorkspaceLeft"></div><div class="productModeV2WorkspaceColumn productModeV2WorkspaceRight"></div>';
      const tabs=document.querySelector('#mainAppTabs');
      const anchor=tabs||header;
      if(anchor?.nextSibling)root.insertBefore(workspace,anchor.nextSibling);
      else root.append(workspace);
    }
    workspace.dataset.appView='clock';

    const imageActive=document.querySelector('#imageEinkView')?.hidden===false;
    workspace.hidden=imageActive;
    workspace.setAttribute('aria-hidden',String(imageActive));
    if(controlsCard){
      controlsCard.hidden=imageActive;
      controlsCard.setAttribute('aria-hidden',String(imageActive));
    }

    const left=workspace.querySelector('.productModeV2WorkspaceLeft');
    const right=workspace.querySelector('.productModeV2WorkspaceRight');
    if(left&&previewCard&&previewCard.parentElement!==left)left.append(previewCard);
    if(left&&controlsCard&&controlsCard.parentElement!==left)left.append(controlsCard);
    if(right&&actionsCard&&actionsCard.parentElement!==right)right.append(actionsCard);
    if(right&&profileCard&&profileCard.parentElement!==right)right.append(profileCard);

    if(advancedBody&&deviceCard&&deviceCard.parentElement!==advancedBody){
      deviceCard.classList.add('productModeV2DeviceAdvanced');
      advancedBody.append(deviceCard);
    }
  }

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

  function jdFromDate(dd,mm,yy){
    const a=Math.floor((14-mm)/12);
    const y=yy+4800-a;
    const m=mm+12*a-3;
    let jd=dd+Math.floor((153*m+2)/5)+365*y+Math.floor(y/4)-Math.floor(y/100)+Math.floor(y/400)-32045;
    if(jd<2299161)jd=dd+Math.floor((153*m+2)/5)+365*y+Math.floor(y/4)-32083;
    return jd;
  }

  function newMoon(k){
    const T=k/1236.85;
    const T2=T*T;
    const T3=T2*T;
    const dr=Math.PI/180;
    let jd=2415020.75933+29.53058868*k+0.0001178*T2-0.000000155*T3;
    jd+=0.00033*Math.sin((166.56+132.87*T-0.009173*T2)*dr);
    const M=359.2242+29.10535608*k-0.0000333*T2-0.00000347*T3;
    const Mp=306.0253+385.81691806*k+0.0107306*T2+0.00001236*T3;
    const F=21.2964+390.67050646*k-0.0016528*T2-0.00000239*T3;
    const C1=(0.1734-0.000393*T)*Math.sin(M*dr)+0.0021*Math.sin(2*M*dr)-0.4068*Math.sin(Mp*dr)+0.0161*Math.sin(2*Mp*dr)-0.0004*Math.sin(3*Mp*dr)+0.0104*Math.sin(2*F*dr)-0.0051*Math.sin((M+Mp)*dr)-0.0074*Math.sin((M-Mp)*dr)+0.0004*Math.sin((2*F+M)*dr)-0.0004*Math.sin((2*F-M)*dr)-0.0006*Math.sin((2*F+Mp)*dr)+0.001*Math.sin((2*F-Mp)*dr)+0.0005*Math.sin((2*Mp+M)*dr);
    const delta=T<-11
      ?0.001+0.000839*T+0.0002261*T2-0.00000845*T3-0.000000081*T*T3
      :-0.000278+0.000265*T+0.000262*T2;
    return jd+C1-delta;
  }

  function newMoonDay(k,timeZone){
    return Math.floor(newMoon(k)+0.5+timeZone/24);
  }

  function sunLongitude(jdn){
    const T=(jdn-2451545.0)/36525;
    const T2=T*T;
    const dr=Math.PI/180;
    const M=357.52910+35999.05030*T-0.0001559*T2-0.00000048*T*T2;
    const L0=280.46645+36000.76983*T+0.0003032*T2;
    const DL=(1.914600-0.004817*T-0.000014*T2)*Math.sin(M*dr)+(0.019993-0.000101*T)*Math.sin(2*M*dr)+0.000290*Math.sin(3*M*dr);
    let L=(L0+DL)*dr;
    L-=Math.PI*2*Math.floor(L/(Math.PI*2));
    return L;
  }

  function sunLongitudeSector(dayNumber,timeZone){
    return Math.floor(sunLongitude(dayNumber-0.5-timeZone/24)/Math.PI*6);
  }

  function lunarMonth11(year,timeZone){
    const off=jdFromDate(31,12,year)-2415021;
    const k=Math.floor(off/29.530588853);
    let nm=newMoonDay(k,timeZone);
    if(sunLongitudeSector(nm,timeZone)>=9)nm=newMoonDay(k-1,timeZone);
    return nm;
  }

  function leapMonthOffset(a11,timeZone){
    const k=Math.floor(0.5+(a11-2415021.076998695)/29.530588853);
    let last=0;
    let i=1;
    let arc=sunLongitudeSector(newMoonDay(k+i,timeZone),timeZone);
    do{
      last=arc;
      i+=1;
      arc=sunLongitudeSector(newMoonDay(k+i,timeZone),timeZone);
    }while(arc!==last&&i<14);
    return i-1;
  }

  function solarToLunar(date,timeZone=7){
    const dd=date.getDate();
    const mm=date.getMonth()+1;
    const yy=date.getFullYear();
    const dayNumber=jdFromDate(dd,mm,yy);
    const k=Math.floor((dayNumber-2415021.076998695)/29.530588853);
    let monthStart=newMoonDay(k+1,timeZone);
    if(monthStart>dayNumber)monthStart=newMoonDay(k,timeZone);
    let a11=lunarMonth11(yy,timeZone);
    let b11=a11;
    let lunarYear;
    if(a11>=monthStart){
      lunarYear=yy;
      a11=lunarMonth11(yy-1,timeZone);
    }else{
      lunarYear=yy+1;
      b11=lunarMonth11(yy+1,timeZone);
    }
    const lunarDay=dayNumber-monthStart+1;
    const diff=Math.floor((monthStart-a11)/29);
    let lunarLeap=0;
    let lunarMonth=diff+11;
    if(b11-a11>365){
      const leapDiff=leapMonthOffset(a11,timeZone);
      if(diff>=leapDiff){
        lunarMonth=diff+10;
        if(diff===leapDiff)lunarLeap=1;
      }
    }
    if(lunarMonth>12)lunarMonth-=12;
    if(lunarMonth>=11&&diff<4)lunarYear-=1;
    return {day:lunarDay,month:lunarMonth,year:lunarYear,leap:lunarLeap};
  }

  function getClassicCadence(){
    return CLASSIC_CADENCES.includes(classicCadence)?classicCadence:5;
  }

  function syncClassicCadenceButtons(){
    document.querySelectorAll('[data-classic-cadence]').forEach(button=>{
      const selected=Number(button.dataset.classicCadence)===getClassicCadence();
      button.classList.toggle('selected',selected);
      button.setAttribute('aria-pressed',String(selected));
    });
  }

  function minuteLabelsForCadence(cadence){
    if(cadence<=5)return [5,10,15,20,25,30,35,40,45,50,55];
    const labels=[];
    for(let minute=cadence;minute<60;minute+=cadence)labels.push(minute);
    return labels;
  }

  function drawCenteredText(ctx,text,x,y,font){
    ctx.save();
    ctx.font=font;
    ctx.textAlign='center';
    ctx.textBaseline='middle';
    ctx.fillText(String(text),x,y);
    ctx.restore();
  }

  function addTicks(face){
    for(let index=0;index<12;index++){
      const tick=document.createElement('span');
      tick.className=`productAnalogTick${index%3===0?' major':''}`;
      tick.style.transform=`rotate(${index*30}deg)`;
      face.append(tick);
    }
  }

  function ensureClassicWebPreviewCanvas(){
    const deviceCanvas=document.getElementById('canvas');
    const wrap=deviceCanvas?.closest('.canvasWrap');
    if(!deviceCanvas||!wrap)return null;

    let webCanvas=document.getElementById('classicWebPreview');
    if(!webCanvas){
      webCanvas=document.createElement('canvas');
      webCanvas.id='classicWebPreview';
      webCanvas.className='classicWebPreview';
      webCanvas.width=1000;
      webCanvas.height=488;
      webCanvas.setAttribute('aria-label','Xem trước Đồng hồ kim độ phân giải cao');
      deviceCanvas.insertAdjacentElement('afterend',webCanvas);
    }
    deviceCanvas.classList.add('classicDeviceCanvasHidden');
    return webCanvas;
  }

  function hideClassicWebPreviewCanvas(){
    document.getElementById('canvas')?.classList.remove('classicDeviceCanvasHidden');
    document.getElementById('classicWebPreview')?.remove();
  }

  function drawClassicScene(canvas,now,cadence){
    const ctx=canvas?.getContext?.('2d');
    if(!canvas||!ctx||!canvas.width||!canvas.height)return;

    const hours=now.getHours();
    const actualMinutes=now.getMinutes();
    const displayMinutes=cadence===1?actualMinutes:Math.floor(actualMinutes/cadence)*cadence;
    const weekdays=['CN','T2','T3','T4','T5','T6','T7'];
    const dateLabel=`${weekdays[now.getDay()]}  ${pad(now.getDate())}/${pad(now.getMonth()+1)}/${now.getFullYear()}`;
    const lunar=solarToLunar(now);
    const lunarLabel=`ÂM LỊCH ${pad(lunar.day)}/${pad(lunar.month)}${lunar.leap?' NHUẬN':''}`;

    ctx.save();
    ctx.setTransform(canvas.width/250,0,0,canvas.height/122,0,0);
    ctx.imageSmoothingEnabled=true;
    ctx.fillStyle='#fff';
    ctx.fillRect(0,0,250,122);
    ctx.fillStyle='#000';
    ctx.strokeStyle='#000';
    ctx.lineCap='round';
    ctx.lineJoin='round';

    ctx.font='700 9px Arial, sans-serif';
    ctx.fillText('ĐỒNG HỒ KIM',10,14);
    ctx.font='700 8px Arial, sans-serif';
    ctx.fillText(dateLabel,10,27);
    ctx.font='800 40px ui-monospace, SFMono-Regular, Consolas, monospace';
    ctx.fillText(`${pad(hours)}:${pad(displayMinutes)}`,7,75);
    ctx.font='700 7px Arial, sans-serif';
    ctx.fillText(lunarLabel,10,108);

    const cx=202,cy=61,outerRadius=47,hourLabelRadius=31.5;
    ctx.lineWidth=1.7;
    ctx.beginPath();
    ctx.arc(cx,cy,outerRadius,0,Math.PI*2);
    ctx.stroke();

    for(let hour=1;hour<=12;hour++){
      const angle=(hour*Math.PI/6)-Math.PI/2;
      const longTick=hour%2===0;
      const tickOuter=outerRadius-1.2;
      const tickInner=outerRadius-(longTick?5.0:3.0);
      ctx.lineWidth=longTick?1.6:1.05;
      ctx.beginPath();
      ctx.moveTo(cx+Math.cos(angle)*tickInner,cy+Math.sin(angle)*tickInner);
      ctx.lineTo(cx+Math.cos(angle)*tickOuter,cy+Math.sin(angle)*tickOuter);
      ctx.stroke();
      drawCenteredText(ctx,hour,cx+Math.cos(angle)*hourLabelRadius,cy+Math.sin(angle)*hourLabelRadius,'800 8.2px Arial, sans-serif');
    }

    /*
     * Inner minute ring mirrors the physical target.
     * Keep it well inside the hour numerals so the two scales do not
     * collide on the 250x122 output.
     */
    for(let minute=0;minute<60;minute++){
      const angle=(minute*Math.PI/30)-Math.PI/2;
      const major=minute%5===0;
      const inner=major?19:21;
      const outer=22;

      ctx.lineWidth=major?1.15:.72;
      ctx.beginPath();
      ctx.moveTo(
        cx+Math.cos(angle)*inner,
        cy+Math.sin(angle)*inner
      );
      ctx.lineTo(
        cx+Math.cos(angle)*outer,
        cy+Math.sin(angle)*outer
      );
      ctx.stroke();
    }

    const hourAngle=(((hours%12)+(displayMinutes/60))*Math.PI/6)-Math.PI/2;
    const minuteAngle=(displayMinutes*Math.PI/30)-Math.PI/2;
    ctx.lineWidth=4.1;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(hourAngle)*14,cy+Math.sin(hourAngle)*14);
    ctx.stroke();
    ctx.lineWidth=2.05;
    ctx.beginPath();
    ctx.moveTo(cx,cy);
    ctx.lineTo(cx+Math.cos(minuteAngle)*20.5,cy+Math.sin(minuteAngle)*20.5);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(cx,cy,3.1,0,Math.PI*2);
    ctx.fill();
    ctx.restore();
  }

  function drawClassicCanvas(){
    const deviceCanvas=document.getElementById('canvas');
    const deviceCtx=deviceCanvas?.getContext?.('2d');
    if(!deviceCanvas||!deviceCtx||!deviceCanvas.width||!deviceCanvas.height)return;

    if(!savedCanvasPreview){
      try{
        savedCanvasPreview={width:deviceCanvas.width,height:deviceCanvas.height,image:deviceCtx.getImageData(0,0,deviceCanvas.width,deviceCanvas.height)};
      }catch{}
    }

    const now=currentClockDate();
    const cadence=getClassicCadence();
    drawClassicScene(deviceCanvas,now,cadence);
    const webCanvas=ensureClassicWebPreviewCanvas();
    if(webCanvas)drawClassicScene(webCanvas,now,cadence);

    const note=document.querySelector('.productClassicNote');
    if(note&&!note.hidden)note.textContent=`Đồng hồ kim preview web độ phân giải cao · chu kỳ ${cadence} phút · output e-ink 250×122 xử lý riêng.`;
  }

  function restoreCanvasPreview(){
    const canvas=document.getElementById('canvas');
    const ctx=canvas?.getContext?.('2d');
    if(canvas&&ctx&&savedCanvasPreview&&canvas.width===savedCanvasPreview.width&&canvas.height===savedCanvasPreview.height){
      try{ctx.putImageData(savedCanvasPreview.image,0,0);}catch{}
    }
    savedCanvasPreview=null;
    hideClassicWebPreviewCanvas();
  }

  function createClockCard(){
    if(document.querySelector('.productProfileClock'))return null;
    ensureClassicCadenceStyles();
    const cadenceButtons=CLASSIC_CADENCES.map(value=>`<button type="button" data-classic-cadence="${value}" aria-pressed="${value===classicCadence}">${value}p</button>`).join('');
    const card=document.createElement('div');
    card.className='productProfileClock';
    card.dataset.einkPremiumClock='v2-profile';
    card.innerHTML=`<div class="productClockCopy"><div class="productClockEyebrow">Đồng hồ kim</div><div class="productClockTime" aria-live="polite">--:--</div><div class="productClockMeta"><strong class="productClockDate">--</strong><span class="productClockSource">Giờ trình duyệt</span></div></div><div class="productAnalogClock" aria-hidden="true"><span class="productAnalogHand productAnalogHour"></span><span class="productAnalogHand productAnalogMinute"></span><span class="productAnalogHand productAnalogSecond"></span><span class="productAnalogCenter"></span></div><div class="productClockCadence" aria-label="Chu kỳ làm mới Đồng hồ kim">${cadenceButtons}</div>`;
    addTicks(card.querySelector('.productAnalogClock'));
    syncClassicCadenceButtons();
    return card;
  }

  function updateClockCard(card){
    if(!card?.isConnected)return;
    const deviceDate=parseDeviceClock();
    const now=deviceDate||new Date();
    const hours=now.getHours(),minutes=now.getMinutes(),seconds=now.getSeconds();
    card.querySelector('.productClockTime').textContent=`${pad(hours)}:${pad(minutes)}`;
    card.querySelector('.productClockDate').textContent=new Intl.DateTimeFormat('vi-VN',{weekday:'long',day:'2-digit',month:'2-digit',year:'numeric'}).format(now);
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
    if(window.__einkCustomDeviceApplyReady){
      delete apply.dataset.classicPreview;
      if(apply.textContent==='Preview web \u2014 ch\u01B0a \u00E1p d\u1EE5ng')apply.textContent='\u00C1p d\u1EE5ng l\u00EAn m\u00E0n';
      return;
    }
    if(active){
      if(!apply.dataset.classicOriginalLabel)apply.dataset.classicOriginalLabel=apply.textContent||'\u00C1p d\u1EE5ng l\u00EAn m\u00E0n';
      apply.dataset.classicPreview='true';
      apply.textContent='Preview web \u2014 ch\u01B0a \u00E1p d\u1EE5ng';
      apply.disabled=true;
      apply.setAttribute('aria-disabled','true');
    }else if(apply.dataset.classicPreview==='true'){
      apply.textContent=apply.dataset.classicOriginalLabel||'\u00C1p d\u1EE5ng l\u00EAn m\u00E0n';
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
    const deviceButtons=[...document.querySelectorAll('#productPresetRow button[data-layout-profile]')].filter(button=>button!==classicButton);
    if(!profile||!select||!card)return;
    profile.dataset.webProfile=active?CLASSIC_VALUE:'device';
    card.hidden=!active;
    classicButton?.classList.toggle('selected',active);
    deviceButtons.forEach(button=>button.classList.toggle('selected',!active&&button.dataset.layoutProfile===select.value));
    syncClassicApply(active);
    syncClassicCadenceButtons();
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
      option.textContent='Đồng hồ kim — Số + Kim';
      select.append(option);
    }
    let classicButton=row.querySelector('[data-eink-classic-profile]');
    if(!classicButton){
      classicButton=document.createElement('button');
      classicButton.type='button';
      classicButton.dataset.einkClassicProfile='true';
      classicButton.dataset.layoutProfile=CLASSIC_VALUE;
      classicButton.textContent='Đồng hồ kim';
      row.append(classicButton);
      row.style.setProperty('grid-template-columns','repeat(2,minmax(0,1fr))','important');
    }
    if(!profile.querySelector('.productClassicNote')){
      const note=document.createElement('p');
      note.className='productClassicNote';
      note.textContent='Đồng hồ kim preview web độ phân giải cao. Output e-ink thật xử lý riêng ở bước firmware.';
      note.hidden=true;
      row.insertAdjacentElement('afterend',note);
    }
    return true;
  }

  function renderClassicState(active){
    if(active)window.EINK_WEEK_PREVIEW?.deactivate?.();
    setClassicUi(active);
    const note=document.querySelector('.productClassicNote');
    if(note)note.hidden=!active;
    if(active)drawClassicCanvas();
    const status=document.getElementById('profileStatus');
    if(active&&status)status.textContent='Đang xem Đồng hồ kim bằng web preview độ phân giải cao. Profile e-ink trên thiết bị chưa thay đổi.';
  }

  window.EINK_CLASSIC_PREVIEW={
    activate:()=>renderClassicState(true),
    deactivate:()=>renderClassicState(false),
    isActive:()=>document.querySelector('.productModeV2Profiles')?.dataset.webProfile===CLASSIC_VALUE
  };

  function mountPremiumClock(){
    ensureOwnerPriorityLayout();
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
    ensureOwnerPriorityLayout();
    let restoreClassic=false;
    try{restoreClassic=localStorage.getItem(CLASSIC_STORAGE_KEY)===CLASSIC_VALUE;}catch{}
    renderClassicState(restoreClassic);
    updateClockCard(card);
    if(!window.__einkPremiumClockTimer){
      window.__einkPremiumClockTimer=setInterval(()=>{
        ensureOwnerPriorityLayout();
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
    const classicCadenceButton=event.target.closest?.('[data-classic-cadence]');
    if(classicCadenceButton){
      event.preventDefault();
      classicCadence=Number(classicCadenceButton.dataset.classicCadence);
      syncClassicCadenceButtons();
      drawClassicCanvas();
      return;
    }
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
    ensureClassicCadenceStyles();
    ensureOwnerPriorityLayout();
    if(mountPremiumClock())return;
    const observer=new MutationObserver(()=>{
      ensureOwnerPriorityLayout();
      if(mountPremiumClock())observer.disconnect();
    });
    observer.observe(document.documentElement,{childList:true,subtree:true});
    setTimeout(()=>observer.disconnect(),15000);
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',installPremiumClock,{once:true});
  else installPremiumClock();
})();
