'use strict';

(() => {
  const theme=document.createElement('link');
  theme.rel='stylesheet';
  theme.href='premium-theme.css';
  theme.dataset.einkTheme='premium-v1';
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
})();
