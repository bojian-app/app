// Marketplace-only page controls and watermarks; exports do not load this script.
(() => {
  const pages = document.getElementById('pages');
  const options = window.bojianPreviewOptions || {};
  const sheets = [];
  let author = String(options.author || '');
  let initialPositioned = false;
  let fullscreen = false;
  let inlinePosition = null;
  let anchorPage = null;
  let restorePosition = null;
  let frame = 0;
  let actionFrame = 0;
  let lastActions = "";
  Object.assign(pages.style, {width:'100%', padding:'0', margin:'0', position:'relative'});

  function watermarkImage() {
    const tile = document.createElement('canvas');
    tile.width = 260;
    tile.height = 180;
    const paint = tile.getContext('2d');
    paint.translate(130, 90);
    paint.rotate(-Math.PI / 7);
    paint.font = '500 28px ResumeDocument, sans-serif';
    paint.fillStyle = 'rgba(51,65,85,0.14)';
    paint.textAlign = 'center';
    paint.textBaseline = 'middle';
    paint.fillText('© ' + author, 0, 0, 230);
    return tile.toDataURL('image/png');
  }
  let watermark = watermarkImage();
  window.updatePreviewAuthor = value => {
    author = String(value || '');
    watermark = watermarkImage();
    for (const sheet of sheets) sheet.watermark.style.backgroundImage = `url("${watermark}")`;
  };
  document.fonts.ready.then(() => window.updatePreviewAuthor(author));

  // Resize the existing papers instead of fetching, loading fonts and paginating again.
  window.setPreviewMode = (expanded, index) => {
    expanded = Boolean(expanded);
    if (expanded === fullscreen) return;
    fullscreen = expanded;
    if (fullscreen) {
      if (inlinePosition === null) inlinePosition = window.scrollY;
      anchorPage = Math.max(0, Number(index) || 0);
      restorePosition = null;
    } else {
      anchorPage = null;
      restorePosition = inlinePosition ?? 0;
      inlinePosition = null;
    }
    scheduleFit();
  };

  function fit() {
    frame = 0;
    const scale = document.documentElement.clientWidth / 794;
    for (const sheet of sheets) {
      sheet.page.style.transform = `scale(${scale})`;
      sheet.wrapper.style.height = `${1123 * scale}px`;
    }
    pages.style.paddingBottom = fullscreen ? `${Math.max(0, window.innerHeight - 1123 * scale)}px` : '0';
    if (!initialPositioned && sheets.length) {
      initialPositioned = true;
      const index = Math.max(0, Math.min(sheets.length - 1, Number(options.initialPage) || 0));
      window.scrollTo(0, sheets[index].wrapper.offsetTop);
    }
    // Native view resize and the bridge message can arrive in either order.
    if (anchorPage !== null && sheets.length) {
      window.scrollTo(0, sheets[Math.min(sheets.length - 1, anchorPage)].wrapper.offsetTop);
    } else if (restorePosition !== null) {
      window.scrollTo(0, restorePosition);
    }
    scheduleActions();
  }
  // Buttons live in Flutter, outside the browser's pinch-zoom coordinate space.
  // Only send visible page bounds; scrolling never rebuilds the native WebView.
  function publishActions() {
    actionFrame = 0;
    if (!options.showPageActions) return;
    const viewport = window.visualViewport;
    const height = viewport?.height || window.innerHeight;
    const offset = viewport?.offsetTop || 0;
    const items = [];
    if (!fullscreen && height > 0) {
      for (let index = 0; index < sheets.length; index++) {
        const rect = sheets[index].wrapper.getBoundingClientRect();
        const top = Math.max(0, rect.top - offset);
        const bottom = Math.min(height, rect.bottom - offset);
        if (bottom <= top) continue;
        items.push({index, top: Math.round(top / height * 10000) / 10000,
          bottom: Math.round(bottom / height * 10000) / 10000});
      }
    }
    const message = JSON.stringify({type:'page-actions', items});
    if (message !== lastActions) {
      lastActions = message;
      window.BojianPages?.postMessage(message);
    }
  }
  function scheduleActions() {
    if (!actionFrame) actionFrame = requestAnimationFrame(publishActions);
  }
  window.openPreviewPage = index => {
    if (fullscreen || !Number.isInteger(index) || index < 0 || index >= sheets.length) return;
    inlinePosition = window.scrollY;
    window.BojianPages?.postMessage(JSON.stringify({type:'open-page', index}));
  };

  function scheduleFit() {
    if (!frame) frame = requestAnimationFrame(fit);
  }
  function decorate() {
    for (const page of [...pages.children].filter(node => node.classList.contains('paper'))) {
      const index = sheets.length;
      const wrapper = document.createElement('section');
      wrapper.setAttribute('aria-label', `简历第 ${index + 1} 页`);
      Object.assign(wrapper.style, {position:'relative', width:'100%', margin:'0 0 20px', overflow:'hidden'});
      pages.insertBefore(wrapper, page);
      wrapper.appendChild(page);
      Object.assign(page.style, {position:'absolute', left:'0', top:'0', margin:'0', transformOrigin:'top left', boxSizing:'border-box', outline:'1px solid #e8ebf0', outlineOffset:'-1px'});
      // Each watermark scrolls and zooms with its paper; template CSS cannot restyle it.
      const host = document.createElement('div');
      host.setAttribute('aria-hidden', 'true');
      for (const [key, value] of Object.entries({position:'absolute', inset:'0', 'z-index':'2147483646', 'pointer-events':'none', overflow:'hidden'})) {
        host.style.setProperty(key, value, 'important');
      }
      const shadow = host.attachShadow({mode:'closed'});
      const layer = document.createElement('div');
      Object.assign(layer.style, {position:'absolute', inset:'0', backgroundImage:`url("${watermark}")`, backgroundRepeat:'repeat', backgroundSize:'260px 180px', pointerEvents:'none'});
      shadow.appendChild(layer);
      page.appendChild(host);
      const sheet = {wrapper, page, watermark:layer};
      sheets.push(sheet);
    }
    scheduleFit();
  }
  new MutationObserver(decorate).observe(pages, {childList:true});
  window.addEventListener('resize', scheduleFit);
  window.addEventListener('scroll', scheduleActions, {passive:true});
  window.visualViewport?.addEventListener('resize', scheduleActions, {passive:true});
  window.visualViewport?.addEventListener('scroll', scheduleActions, {passive:true});
  window.addEventListener('pointerdown', () => {
    anchorPage = null;
    restorePosition = null;
  }, {passive:true});
  decorate();
})();
