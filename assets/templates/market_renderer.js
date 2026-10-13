// Bind server-sanitized template DOM to resume fields, then paginate the DOM.
// Preview and export both use these exact pages; no PDF preview is involved.
(function () {
  const tell = value => BojianPages.postMessage(JSON.stringify(value));
  const scalar = (scope, key) => key === 'photo' ? payload.photo : scope[key] ?? payload.fields[key] ?? '';
  const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function replaceText(element, scope) {
    function snapshot() {
      const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
      const nodes=[]; let n, text='';
      while ((n=walker.nextNode())) { nodes.push({node:n,start:text.length}); text+=n.nodeValue; }
      return {nodes,text};
    }
    function replaceRange(nodes,from,to,value) {
      for (const item of nodes) {
        const end=item.start+item.node.nodeValue.length;
        if (item.start<to && end>from) {
          const a=Math.max(0,from-item.start),b=Math.min(item.node.nodeValue.length,to-item.start);
          item.node.nodeValue=item.node.nodeValue.slice(0,a)+(item.start<=from?value:'')+item.node.nodeValue.slice(b);
        }
      }
    }
    // Inline conditions retain all spans inside a visible branch.
    for (let pass=0;pass<20;pass++) {
      const state=snapshot();
      const conditions=[...state.text.matchAll(/\{\{#if\s+([a-z_]+)\}\}((?:(?!\{\{#if)[\s\S])*?)\{\{\/if\}\}/g)].reverse();
      if (!conditions.length) break;
      for (const token of conditions) {
        const start=token.index,end=start+token[0].length;
        if (scalar(scope,token[1])) {
          replaceRange(state.nodes,end-7,end,'');
          replaceRange(state.nodes,start,start+token[0].indexOf('}}')+2,'');
        } else replaceRange(state.nodes,start,end,'');
      }
    }
    const state=snapshot();
    for (const token of [...state.text.matchAll(/\{\{\s*([a-z_]+)\s*\}\}/g)].reverse()) {
      if (token[1] === 'photo') continue;
      replaceRange(state.nodes,token.index,token.index+token[0].length,String(scalar(scope,token[1])));
    }
  }
  function bind(parent, scope) {
    let index = 0;
    while (index < parent.children.length) {
      const child = parent.children[index], text = child.textContent.trim();
      const loop = text.match(/^\{\{#([a-z_]+)\}\}$/);
      const condition = text.match(/^\{\{#if\s+([a-z_]+)\}\}$/);
      if (loop || condition) {
        const key = (loop || condition)[1], close = condition ? '{{/if}}' : '{{/'+key+'}}';
        let end = index+1, depth = 1;
        for (; end < parent.children.length; end++) {
          const next = parent.children[end].textContent.trim();
          if (condition && /^\{\{#if\s+/.test(next)) depth++;
          if (next === close && --depth === 0) break;
          // A loop has no nested loops; only matching endings affect depth.
          if (next !== close && !(condition && /^\{\{#if\s+/.test(next))) depth = Math.max(1,depth);
        }
        if (end >= parent.children.length) throw new Error('模板循环或条件格式不完整');
        const originals = Array.from(parent.children).slice(index+1,end);
        const values = loop ? scalar(scope,key) : (scalar(scope,key) ? [scope] : []);
        if (!Array.isArray(values)) throw new Error('模板循环字段无效');
        const fragment = document.createDocumentFragment();
        for (const value of values) {
          const holder = document.createElement('div');
          originals.forEach(item => holder.appendChild(item.cloneNode(true)));
          bind(holder, value);
          while (holder.firstChild) fragment.appendChild(holder.firstChild);
        }
        const closing = parent.children[end];
        const inserted = fragment.childElementCount;
        parent.insertBefore(fragment,child);
        originals.forEach(item => item.remove()); closing.remove(); child.remove();
        // Inserted nodes are already bound; restart harmlessly handles shifted indexes.
        index += inserted; continue;
      }
      if (child.matches('p,h1,h2,h3,h4,h5,h6,li') || child.children.length === 0) replaceText(child,scope);
      else bind(child,scope);
      index++;
    }
  }
  async function start() {
    const flow = document.getElementById('flow');
    flow.innerHTML = payload.html;
    flow.querySelectorAll('script,iframe,object,embed,form,link,style').forEach(n=>n.remove());
    flow.querySelectorAll('*').forEach(n=>Array.from(n.attributes).forEach(a=>{ if (/^on/i.test(a.name)) n.removeAttribute(a.name); }));
    bind(flow,payload.fields);
    const margins = {top:61.5,bottom:61.5,left:61.5,right:61.5};
    const probe = document.createElement('div'); document.body.appendChild(probe);
    for (const sheet of document.styleSheets) for (const rule of sheet.cssRules) {
      if (rule.type === CSSRule.PAGE_RULE) {
        for (const side of Object.keys(margins)) {
          const value = rule.style.getPropertyValue('margin-'+side);
          if (value) { probe.style.width=value; margins[side]=parseFloat(getComputedStyle(probe).width); }
        }
      }
    }
    probe.remove();
    const width = 794-margins.left-margins.right, height = 1123-margins.top-margins.bottom;
    if (width < 100 || height < 100) throw new Error('模板页边距无效');
    flow.style.width=width+'px'; flow.style.height=height+'px'; flow.style.columnWidth=width+'px';
    flow.querySelectorAll('*').forEach(n=>{
      const style = getComputedStyle(n);
      if (['page','always'].includes(style.breakBefore)) n.style.breakBefore='column';
      if (['page','always'].includes(style.breakAfter)) n.style.breakAfter='column';
    });
    flow.querySelectorAll('img').forEach(image=>{
      if ([image.alt,image.title].some(text=> /\{\{\s*photo\s*\}\}/.test(text))) {
        if (payload.photo) image.src = payload.photo; else image.remove();
      }
    });
    // A text photo marker can also be used by HTML templates.
    flow.querySelectorAll('p').forEach(p=>{
      if (p.textContent.trim() === '{{photo}}') {
        p.innerHTML = payload.photo ? '<img style="width:75pt;height:90pt;object-fit:cover" src="'+escape(payload.photo)+'">' : '';
      }
    });
    if (/\{\{[#/]/.test(flow.textContent)) throw new Error('模板占位结构暂不支持');
    await document.fonts.ready;
    await Promise.all(Array.from(flow.querySelectorAll('img')).map(image=>new Promise((resolve,reject)=>{
      if (image.complete) return image.naturalWidth ? resolve() : reject(new Error('模板图片不可用'));
      image.onload = resolve; image.onerror = ()=>reject(new Error('模板图片不可用'));
      setTimeout(()=>reject(new Error('模板图片加载超时')),15000);
    })));
    const count = Math.max(1, Math.ceil((flow.scrollWidth+1)/(width+32)));
    if (count > 30) throw new Error('模板页数过多');
    const pages = document.getElementById('pages');
    for (let i=0;i<count;i++) {
      const page = document.createElement('div'); page.className='paper';
      const inner = document.createElement('div'); inner.className='inner';
      Object.assign(inner.style,{left:margins.left+'px',top:margins.top+'px',width:width+'px',height:height+'px'});
      const clone = flow.cloneNode(true); clone.removeAttribute('id'); clone.className='flow';
      clone.style.left = -(width+32)*i+'px'; inner.appendChild(clone); page.appendChild(inner); pages.appendChild(page);
    }
    flow.remove();
    window.pageCount = count;
    tell({type:'ready',count});
  }
  window.capturePage = async function(index, token) {
    try {
      const page = document.querySelectorAll('.paper')[index];
      if (!page) throw new Error('页面不存在');
      const canvas = await html2canvas(page,{scale:3,backgroundColor:'#ffffff',logging:false,useCORS:false,allowTaint:false});
      tell({type:'page',token,index,data:canvas.toDataURL('image/png').split(',')[1]});
      canvas.width=0; canvas.height=0;
    } catch(e) { tell({type:'error',token,message:String(e.message||e)}); }
  };
  start().catch(e=>tell({type:'error',message:String(e.message||e)}));
})();
