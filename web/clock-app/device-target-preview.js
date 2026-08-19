'use strict';

(() => {
  const WIDTH=250;
  const HEIGHT=122;
  const TARGET_ID='deviceTargetPreview';
  const STYLE_ID='einkDeviceTargetPreviewStyle';
  const CLASSIC_PROFILE_ID=3;
  const WEEK_PROFILE_ID=4;
  let mode='web';

  function ensureStyles(){
    if(document.getElementById(STYLE_ID))return;
    const style=document.createElement('style');
    style.id=STYLE_ID;
    style.textContent=`
      .productPreviewModeBar{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:0 0 12px;padding:8px 10px;border:1px solid rgba(145,176,205,.13);border-radius:12px;background:rgba(5,13,23,.42)}
      .productPreviewModeCopy{min-width:0;color:#8fa4bb;font-size:.72rem;line-height:1.35}
      .productPreviewModeButtons{display:flex;gap:5px;flex:0 0 auto}
      .productPreviewModeButtons button{min-height:32px!important;padding:6px 10px!important;border-radius:9px!important;font-size:.72rem!important}
      .productPreviewModeButtons button.selected{border-color:rgba(91,220,255,.42)!important;background:linear-gradient(135deg,rgba(91,220,255,.95),rgba(48,183,230,.95))!important;color:#03121b!important}
      .productModeV2Preview canvas.deviceTargetPreview{display:block!important;width:min(100%,500px)!important;height:auto!important;max-width:100%!important;image-rendering:pixelated!important;image-rendering:crisp-edges!important;filter:none!important;background:#fff!important}
      .productModeV2Preview canvas.deviceTargetPreview[hidden]{display:none!important}
      .devicePreviewSourceHidden{display:none!important}
      @media(max-width:560px){.productPreviewModeBar{align-items:stretch;flex-direction:column}.productPreviewModeButtons{display:grid;grid-template-columns:1fr 1fr;width:100%}.productPreviewModeButtons button{width:100%}}
    `;
    document.head.append(style);
  }

  function ensureControls(){
    const preview=document.querySelector('.productModeV2Preview');
    const wrap=preview?.querySelector('.canvasWrap');
    if(!preview||!wrap)return false;
    if(preview.querySelector('.productPreviewModeBar'))return true;

    const bar=document.createElement('div');
    bar.className='productPreviewModeBar';
    bar.innerHTML=`
      <div class="productPreviewModeCopy">
        <strong>Chế độ xem</strong><br>
        Web rõ để duyệt giao diện · E-ink 250×122 để kiểm tra raster 1-bit.
      </div>
      <div class="productPreviewModeButtons" role="group" aria-label="Chế độ preview">
        <button type="button" data-preview-mode="web" class="selected" aria-pressed="true">Web rõ</button>
        <button type="button" data-preview-mode="device" aria-pressed="false">E-ink 250×122</button>
      </div>`;
    wrap.insertAdjacentElement('beforebegin',bar);
    return true;
  }

  function ensureTargetCanvas(){
    const base=document.getElementById('canvas');
    if(!base)return null;
    let target=document.getElementById(TARGET_ID);
    if(!target){
      target=document.createElement('canvas');
      target.id=TARGET_ID;
      target.className='deviceTargetPreview';
      target.width=WIDTH;
      target.height=HEIGHT;
      target.hidden=true;
      target.setAttribute('aria-label','E-ink 250 by 122 one-bit target preview');
      base.parentElement?.append(target);
    }
    return target;
  }

  function activeSource(){
    const value=customLayout()||document.getElementById('productLayoutSelect')?.value;
    if(value==='week-calendar')return document.getElementById('weekWebPreview')||document.getElementById('canvas');
    if(value==='clock-classic')return document.getElementById('classicWebPreview')||document.getElementById('canvas');
    return document.getElementById('canvas');
  }

  function clearHiddenSources(){
    document.querySelectorAll('.devicePreviewSourceHidden').forEach(node=>node.classList.remove('devicePreviewSourceHidden'));
  }

  function thresholdOneBit(ctx){
    const image=ctx.getImageData(0,0,WIDTH,HEIGHT);
    const data=image.data;
    for(let index=0;index<data.length;index+=4){
      const luminance=(data[index]*0.2126)+(data[index+1]*0.7152)+(data[index+2]*0.0722);
      const value=luminance<178?0:255;
      data[index]=value;
      data[index+1]=value;
      data[index+2]=value;
      data[index+3]=255;
    }
    ctx.putImageData(image,0,0);
  }

  function renderTarget(){
    const target=ensureTargetCanvas();
    const source=activeSource();
    const ctx=target?.getContext?.('2d',{willReadFrequently:true});
    if(!target||!source||!ctx||!source.width||!source.height)return;

    ctx.save();
    ctx.setTransform(1,0,0,1,0,0);
    ctx.clearRect(0,0,WIDTH,HEIGHT);
    ctx.fillStyle='#fff';
    ctx.fillRect(0,0,WIDTH,HEIGHT);
    ctx.imageSmoothingEnabled=true;
    ctx.drawImage(source,0,0,source.width,source.height,0,0,WIDTH,HEIGHT);
    ctx.restore();
    thresholdOneBit(ctx);
  }

  function syncUi(){
    ensureControls();
    const target=ensureTargetCanvas();
    const source=activeSource();
    clearHiddenSources();

    document.querySelectorAll('[data-preview-mode]').forEach(button=>{
      const selected=button.dataset.previewMode===mode;
      button.classList.toggle('selected',selected);
      button.setAttribute('aria-pressed',String(selected));
    });

    if(mode==='device'){
      renderTarget();
      if(source&&source!==target)source.classList.add('devicePreviewSourceHidden');
      if(target)target.hidden=false;
    }else if(target){
      target.hidden=true;
    }
  }

  function setMode(nextMode){
    mode=nextMode==='device'?'device':'web';
    document.documentElement.dataset.einkPreviewMode=mode;
    syncUi();
    document.dispatchEvent(new CustomEvent('eink-preview-mode-change',{detail:{mode}}));
  }

  function customLayout(){
    try{
      if(window.EINK_WEEK_PREVIEW?.isActive?.())return 'week-calendar';
    }catch(_error){}
    const profile=document.querySelector('.productModeV2Profiles');
    if(profile?.dataset.webProfile==='clock-classic')return 'clock-classic';
    const value=document.getElementById('productLayoutSelect')?.value;
    return value==='clock-classic'||value==='week-calendar'?value:'';
  }

  function selectedClassicCadence(){
    const selected=document.querySelector('[data-classic-cadence].selected');
    const value=Number(selected?.dataset.classicCadence||5);
    return [1,5,10,15,30].includes(value)?value:5;
  }

  function deviceApplyAllowed(){
    try{
      const connected=!!server?.connected;
      const conflictingLocked=unifiedDailyUpdateConflicting();
      const locked=conflictingLocked||unifiedDailyUpdateRunning;
      const identityBlocked=connected&&identityCompatibility!=='compatible';
      return connected&&!locked&&!identityBlocked&&productD2State!==null&&productD2State!==0;
    }catch(_error){
      return false;
    }
  }

  function restoreCustomSelection(layout){
    const select=document.getElementById('productLayoutSelect');
    if(select)select.value=layout;
    document.querySelectorAll('#productPresetRow button[data-layout-profile]').forEach(button=>{
      button.classList.toggle('selected',button.dataset.layoutProfile===layout);
    });
  }

  function syncDeviceApplyButton(){
    const layout=customLayout();
    const apply=document.getElementById('profileApply');
    if(!layout||!apply)return;
    restoreCustomSelection(layout);
    delete apply.dataset.classicPreview;
    delete apply.dataset.weekPreview;
    apply.textContent='Áp dụng lên màn';
    apply.disabled=!deviceApplyAllowed();
    if(apply.disabled)apply.setAttribute('aria-disabled','true');
    else apply.removeAttribute('aria-disabled');
  }

  function friendlyApplyStatus(layout){
    restoreCustomSelection(layout);
    const status=document.getElementById('profileStatus');
    if(status)status.textContent=layout==='clock-classic'
      ?'Đồng hồ kim đã áp dụng lên thiết bị.'
      :'Lịch Tuần đã áp dụng lên thiết bị.';
    syncDeviceApplyButton();
  }

  function installDeviceApplyBridge(){
    /* Window capture runs before the older document-capture preview guards. */
    window.addEventListener('click',event=>{
      const apply=event.target.closest?.('#profileApply');
      const layout=customLayout();
      if(!apply||!layout)return;
      event.preventDefault();
      event.stopImmediatePropagation();
      if(!deviceApplyAllowed()){
        syncDeviceApplyButton();
        return;
      }

      try{
        let run;
        if(layout==='clock-classic'){
          const cadence=selectedClassicCadence();
          selectedClockProfile=CLASSIC_PROFILE_ID;
          selectedRefreshMinutes=cadence;
          run=runD2Flow(async()=>{
            await d2ApplyClockPreferences();
            return d2ApplyClockProfile();
          });
        }else{
          selectedClockProfile=WEEK_PROFILE_ID;
          run=runD2Flow(d2ApplyClockProfile);
        }
        if(run&&typeof run.then==='function'){
          run.then(()=>friendlyApplyStatus(layout)).catch(error=>console.error('Profile device apply failed',error));
        }
      }catch(error){
        console.error('Profile device apply bridge failed',error);
      }
    },true);

    if(!window.__einkProfileDeviceApplyTimer){
      window.__einkProfileDeviceApplyTimer=setInterval(syncDeviceApplyButton,250);
    }
  }

  function install(){
    ensureStyles();
    ensureControls();
    ensureTargetCanvas();
    document.documentElement.dataset.einkPreviewMode=mode;
    syncUi();
    installDeviceApplyBridge();

    document.addEventListener('click',event=>{
      const button=event.target.closest?.('[data-preview-mode]');
      if(!button)return;
      event.preventDefault();
      setMode(button.dataset.previewMode);
    },true);

    document.addEventListener('change',event=>{
      if(event.target?.id==='productLayoutSelect')setTimeout(()=>{syncUi();syncDeviceApplyButton();},0);
    },true);

    document.addEventListener('click',event=>{
      if(event.target.closest?.('#productPresetRow button[data-layout-profile]'))setTimeout(()=>{syncUi();syncDeviceApplyButton();},0);
    },true);

    const observer=new MutationObserver(()=>{
      ensureControls();
      ensureTargetCanvas();
      if(mode==='device')setTimeout(syncUi,0);
    });
    observer.observe(document.documentElement,{childList:true,subtree:true});

    if(!window.__einkDeviceTargetPreviewTimer){
      window.__einkDeviceTargetPreviewTimer=setInterval(()=>{
        if(mode==='device')syncUi();
      },1000);
    }
  }

  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',install,{once:true});
  else install();
})();