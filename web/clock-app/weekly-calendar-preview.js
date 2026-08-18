'use strict';

(() => {
  const WEEK_VALUE='week-calendar';
  const WEEK_CANVAS_ID='weekWebPreview';
  const DEVICE_CANVAS_ID='canvas';
  const WEEK_CARD_CLASS='productProfileWeek';
  const WEEK_STYLE_ID='einkWeekCalendarStyle';
  let weekActive=false;

  const pad=value=>String(value).padStart(2,'0');

  function ensureStyles(){
    if(document.getElementById(WEEK_STYLE_ID))return;
    const style=document.createElement('style');
    style.id=WEEK_STYLE_ID;
    style.textContent=`
      .productProfileWeek{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:center;margin:0 0 14px;padding:14px;border:1px solid rgba(91,220,255,.18);border-radius:16px;background:linear-gradient(135deg,rgba(10,22,34,.92),rgba(16,29,43,.88))}
      .productProfileWeek[hidden]{display:none!important}
      .productWeekEyebrow{font-size:.6rem;font-weight:800;letter-spacing:.15em;text-transform:uppercase;color:#7890a7}
      .productWeekTitle{margin:4px 0 3px;font-size:1.15rem;font-weight:850;color:#f7fbff}
      .productWeekMeta{font-size:.76rem;line-height:1.45;color:#9fb2c5}
      .productWeekBadge{display:inline-flex;align-items:center;justify-content:center;min-width:58px;min-height:58px;padding:8px;border:1px solid rgba(91,220,255,.2);border-radius:14px;background:rgba(5,13,23,.5);font-size:1.25rem;font-weight:900;color:#dff7ff}
      .productModeV2Preview canvas.weekDeviceCanvasHidden{display:none!important}
      .productModeV2Preview canvas.weekWebPreview{display:block!important;width:min(100%,1000px)!important;height:auto!important;max-width:100%!important;image-rendering:auto!important;filter:none!important;background:#fff!important}
    `;
    document.head.append(style);
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

  function currentDate(){
    return parseDeviceClock()||new Date();
  }

  function addDays(date,days){
    const next=new Date(date);
    next.setDate(next.getDate()+days);
    return next;
  }

  function mondayOf(date){
    const copy=new Date(date.getFullYear(),date.getMonth(),date.getDate());
    const day=copy.getDay();
    const diff=day===0?-6:1-day;
    copy.setDate(copy.getDate()+diff);
    copy.setHours(12,0,0,0);
    return copy;
  }

  function isoWeekNumber(date){
    const tmp=new Date(Date.UTC(date.getFullYear(),date.getMonth(),date.getDate()));
    const day=tmp.getUTCDay()||7;
    tmp.setUTCDate(tmp.getUTCDate()+4-day);
    const yearStart=new Date(Date.UTC(tmp.getUTCFullYear(),0,1));
    return Math.ceil((((tmp-yearStart)/86400000)+1)/7);
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

  function readTemperature(){
    const candidates=['dailyWeatherTemperature','weatherTemperature','temperature','tempValue'];
    for(const id of candidates){
      const text=(document.getElementById(id)?.textContent||'').trim();
      const match=text.match(/-?\d+(?:[.,]\d+)?\s*°?C/i);
      if(match)return match[0].replace(/\s+/g,'');
    }
    return '--°C';
  }

  function weekData(now){
    const monday=mondayOf(now);
    const days=[];
    for(let index=0;index<7;index++){
      const date=addDays(monday,index);
      days.push({date,lunar:solarToLunar(date)});
    }
    return {monday,days,week:isoWeekNumber(now)};
  }

  function ensureCanvas(){
    const device=document.getElementById(DEVICE_CANVAS_ID);
    if(!device)return null;
    let canvas=document.getElementById(WEEK_CANVAS_ID);
    if(!canvas){
      canvas=document.createElement('canvas');
      canvas.id=WEEK_CANVAS_ID;
      canvas.className='weekWebPreview';
      canvas.width=1000;
      canvas.height=488;
      canvas.setAttribute('aria-label','Lịch tuần web preview high resolution');
      device.insertAdjacentElement('afterend',canvas);
    }
    device.classList.add('weekDeviceCanvasHidden');
    return canvas;
  }

  function restoreCanvas(){
    document.getElementById(DEVICE_CANVAS_ID)?.classList.remove('weekDeviceCanvasHidden');
    document.getElementById(WEEK_CANVAS_ID)?.remove();
  }

  function drawWeek(){
    const canvas=ensureCanvas();
    const ctx=canvas?.getContext?.('2d');
    if(!canvas||!ctx)return;

    const now=currentDate();
    const data=weekData(now);
    const currentKey=`${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
    const monthName=`THÁNG ${now.getMonth()+1}`;
    const rangeEnd=data.days[6].date;
    const rangeLabel=`${pad(data.monday.getDate())}/${pad(data.monday.getMonth()+1)} – ${pad(rangeEnd.getDate())}/${pad(rangeEnd.getMonth()+1)}/${rangeEnd.getFullYear()}`;
    const weekdays=['T2','T3','T4','T5','T6','T7','CN'];

    ctx.save();
    ctx.setTransform(canvas.width/250,0,0,canvas.height/122,0,0);
    ctx.fillStyle='#fff';
    ctx.fillRect(0,0,250,122);
    ctx.fillStyle='#050505';
    ctx.strokeStyle='#050505';
    ctx.textBaseline='middle';

    ctx.font='900 8px Arial, sans-serif';
    ctx.textAlign='left';
    ctx.fillText(`${monthName} · TUẦN ${data.week}`,7,10);
    ctx.font='700 5.3px Arial, sans-serif';
    ctx.textAlign='right';
    ctx.fillText(rangeLabel,243,10);

    const left=6;
    const top=20;
    const gap=2;
    const totalWidth=238;
    const colWidth=(totalWidth-gap*6)/7;
    const colHeight=76;

    data.days.forEach((item,index)=>{
      const x=left+index*(colWidth+gap);
      const y=top;
      const key=`${item.date.getFullYear()}-${item.date.getMonth()}-${item.date.getDate()}`;
      const active=key===currentKey;

      ctx.lineWidth=.7;
      if(active){
        ctx.fillStyle='#050505';
        ctx.fillRect(x,y,colWidth,colHeight);
        ctx.fillStyle='#fff';
      }else{
        ctx.fillStyle='#fff';
        ctx.fillRect(x,y,colWidth,colHeight);
        ctx.strokeStyle='#111';
        ctx.strokeRect(x+.35,y+.35,colWidth-.7,colHeight-.7);
        ctx.fillStyle='#050505';
      }

      ctx.textAlign='center';
      ctx.font='900 6px Arial, sans-serif';
      ctx.fillText(weekdays[index],x+colWidth/2,y+9);

      ctx.font='900 16px Arial, sans-serif';
      ctx.fillText(item.date.getDate(),x+colWidth/2,y+32);

      const lunarLabel=item.lunar.day===1
        ?`1/${item.lunar.month}${item.lunar.leap?'N':''}`
        :String(item.lunar.day);
      ctx.font='800 5.8px Arial, sans-serif';
      ctx.fillText(lunarLabel,x+colWidth/2,y+54);

      ctx.font='700 4.6px Arial, sans-serif';
      ctx.fillText(item.date.getMonth()+1===now.getMonth()+1?'DL':'THÁNG',x+colWidth/2,y+68);
    });

    const currentLunar=solarToLunar(now);
    ctx.fillStyle='#050505';
    ctx.textAlign='left';
    ctx.font='800 6px Arial, sans-serif';
    ctx.fillText(`${weekdays[(now.getDay()+6)%7]} ${pad(now.getDate())}/${pad(now.getMonth()+1)}`,7,108);
    ctx.textAlign='center';
    ctx.font='800 5.6px Arial, sans-serif';
    ctx.fillText(`ÂM ${currentLunar.day}/${currentLunar.month}${currentLunar.leap?'N':''}`,126,108);
    ctx.textAlign='right';
    ctx.fillText(readTemperature(),243,108);

    ctx.restore();
    syncWeekCard(now,data);
  }

  function ensureWeekChoice(){
    const profile=document.querySelector('.productModeV2Profiles');
    const select=document.getElementById('productLayoutSelect');
    const row=document.getElementById('productPresetRow');
    if(!profile||!select||!row)return false;

    if(!select.querySelector(`option[value="${WEEK_VALUE}"]`)){
      const option=document.createElement('option');
      option.value=WEEK_VALUE;
      option.textContent='Lịch Tuần — 7 ngày';
      select.append(option);
    }

    let button=row.querySelector('[data-eink-week-profile]');
    if(!button){
      button=document.createElement('button');
      button.type='button';
      button.dataset.einkWeekProfile='true';
      button.dataset.layoutProfile=WEEK_VALUE;
      button.textContent='Lịch Tuần';
      row.append(button);
    }

    if(!profile.querySelector(`.${WEEK_CARD_CLASS}`)){
      const card=document.createElement('div');
      card.className=WEEK_CARD_CLASS;
      card.hidden=true;
      card.innerHTML='<div><div class="productWeekEyebrow">Week Calendar</div><div class="productWeekTitle">Lịch Tuần</div><div class="productWeekMeta">--</div></div><div class="productWeekBadge">7D</div>';
      const intro=profile.querySelector('.productProfileIntro');
      intro?.insertAdjacentElement('afterend',card);
    }
    return true;
  }

  function syncWeekCard(now,data){
    const card=document.querySelector(`.${WEEK_CARD_CLASS}`);
    if(!card)return;
    const end=data.days[6].date;
    card.querySelector('.productWeekTitle').textContent=`Tháng ${now.getMonth()+1} · Tuần ${data.week}`;
    card.querySelector('.productWeekMeta').textContent=`T2 ${pad(data.monday.getDate())}/${pad(data.monday.getMonth()+1)} → CN ${pad(end.getDate())}/${pad(end.getMonth()+1)} · hôm nay ${pad(now.getDate())}/${pad(now.getMonth()+1)}`;
  }

  function setApplyPreview(active){
    const apply=document.getElementById('profileApply');
    if(!apply)return;
    if(active){
      if(!apply.dataset.weekOriginalLabel)apply.dataset.weekOriginalLabel=apply.textContent||'Áp dụng lên màn';
      apply.dataset.weekPreview='true';
      apply.textContent='Preview web — chưa áp dụng';
      apply.disabled=true;
      apply.setAttribute('aria-disabled','true');
    }else if(apply.dataset.weekPreview==='true'){
      apply.textContent=apply.dataset.weekOriginalLabel||'Áp dụng lên màn';
      apply.disabled=false;
      apply.removeAttribute('aria-disabled');
      delete apply.dataset.weekPreview;
    }
  }

  function setWeekActive(active){
    weekActive=active;
    const select=document.getElementById('productLayoutSelect');
    const card=document.querySelector(`.${WEEK_CARD_CLASS}`);
    const button=document.querySelector('[data-eink-week-profile]');
    if(card)card.hidden=!active;
    button?.classList.toggle('selected',active);
    setApplyPreview(active);

    if(active){
      if(select)select.value=WEEK_VALUE;
      document.querySelector('.productProfileClock')?.setAttribute('hidden','');
      drawWeek();
      const status=document.getElementById('profileStatus');
      if(status)status.textContent='Đang xem Lịch Tuần bằng web preview high-res. Output e-ink thật sẽ xử lý riêng.';
    }else{
      restoreCanvas();
    }
  }

  function install(){
    ensureStyles();
    if(!ensureWeekChoice()){
      const observer=new MutationObserver(()=>{
        if(ensureWeekChoice())observer.disconnect();
      });
      observer.observe(document.documentElement,{childList:true,subtree:true});
      setTimeout(()=>observer.disconnect(),15000);
    }

    document.addEventListener('change',event=>{
      if(event.target?.id!=='productLayoutSelect')return;
      if(event.target.value===WEEK_VALUE){
        event.preventDefault();
        event.stopImmediatePropagation();
        setWeekActive(true);
      }else if(weekActive){
        setWeekActive(false);
      }
    },true);

    document.addEventListener('click',event=>{
      const weekButton=event.target.closest?.('[data-eink-week-profile]');
      if(weekButton){
        event.preventDefault();
        event.stopImmediatePropagation();
        setWeekActive(true);
        return;
      }

      const otherProfile=event.target.closest?.('#productPresetRow button[data-layout-profile]');
      if(otherProfile&&weekActive&&otherProfile.dataset.layoutProfile!==WEEK_VALUE){
        setWeekActive(false);
      }

      const apply=event.target.closest?.('#profileApply');
      if(apply&&weekActive){
        event.preventDefault();
        event.stopImmediatePropagation();
      }
    },true);

    if(!window.__einkWeekPreviewTimer){
      window.__einkWeekPreviewTimer=setInterval(()=>{
        if(weekActive)drawWeek();
      },30000);
    }
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});
  else install();
})();
