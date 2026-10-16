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

// Export live DOM geometry and editable text, never a canvas of the whole page.
window.exportNativeLayout = async function(token) {
  try {
    const sx=595.28/794, sy=841.89/1123;
    const color=value=>{
      const m=value.match(/[\d.]+/g); if(!m || value==='transparent')return 0;
      const a=m.length>3?Math.round(Number(m[3])*255):255;
      return a*16777216+Number(m[0])*65536+Number(m[1])*256+Number(m[2]);
    };
    const baselineCache=new Map();
    function baseline(style) {
      const key=style.font;
      if(baselineCache.has(key))return baselineCache.get(key);
      const probe=document.createElement('div');
      Object.assign(probe.style,{position:'absolute',left:'-10000px',top:'0',font:style.font,whiteSpace:'pre'});
      const span=document.createElement('span');span.textContent='Hg中';
      const marker=document.createElement('span');Object.assign(marker.style,{display:'inline-block',width:'0',height:'0'});
      probe.append(span,marker);document.body.append(probe);
      const range=document.createRange();range.selectNodeContents(span);
      const value=marker.getBoundingClientRect().top-range.getBoundingClientRect().top;
      probe.remove();baselineCache.set(key,value);return value;
    }
    const output=[];
    for(const page of document.querySelectorAll('.paper')) {
      const origin=page.getBoundingClientRect(), clip=page.querySelector('.inner').getBoundingClientRect();
      const visible=r=>r.width>0 && r.height>0 && r.left>=clip.left-.5 && r.right<=clip.right+.5 && r.bottom>clip.top+.5 && r.top<clip.bottom-.5;
      const lines=[],rules=[],pictures=[];
      for(const node of page.querySelectorAll('.flow *')) {
        const style=getComputedStyle(node);
        if(style.display==='none'||style.visibility==='hidden'||Number(style.opacity)===0)continue;
        for(const r of node.getClientRects()) {
          if(!visible(r))continue;
          const background=color(style.backgroundColor);
          if(background>>>24)rules.push({x:(r.left-origin.left)*sx,y:(r.top-origin.top)*sy,width:r.width*sx,height:r.height*sy,thickness:0,color:background});
          for(const side of ['Top','Bottom']) {
            const thickness=parseFloat(style['border'+side+'Width']);
            if(thickness && style['border'+side+'Style']!=='none')rules.push({x:(r.left-origin.left)*sx,y:((side==='Top'?r.top:r.bottom)-origin.top)*sy,width:r.width*sx,height:0,thickness:thickness*sy,color:color(style['border'+side+'Color'])});
          }
          for(const side of ['Left','Right']) {
            const thickness=parseFloat(style['border'+side+'Width']);
            if(thickness && style['border'+side+'Style']!=='none')rules.push({x:((side==='Left'?r.left:r.right)-origin.left)*sx,y:(r.top-origin.top)*sy,width:thickness*sx,height:r.height*sy,thickness:0,color:color(style['border'+side+'Color'])});
          }
        }
      }
      const walker=document.createTreeWalker(page.querySelector('.flow'),NodeFilter.SHOW_TEXT);
      let node;
      while((node=walker.nextNode())) {
        const parent=node.parentElement,style=getComputedStyle(parent);
        if(style.display==='none'||style.visibility==='hidden'||!node.nodeValue.trim())continue;
        const segments=typeof Intl.Segmenter==='function'?[...new Intl.Segmenter('zh',{granularity:'grapheme'}).segment(node.nodeValue)].map(s=>({text:s.segment,index:s.index})):Array.from(node.nodeValue).map((text,i,a)=>({text,index:a.slice(0,i).join('').length}));
        let current=null;
        for(const part of segments) {
          const range=document.createRange();range.setStart(node,part.index);range.setEnd(node,part.index+part.text.length);
          const r=range.getBoundingClientRect();
          if(!visible(r)||/[\r\n]/.test(part.text)){current=null;continue;}
          if(!current||Math.abs(current.rawTop-r.top)>.5) {
            const size=parseFloat(style.fontSize)*sx;
            const span={text:'',x:(r.left-origin.left)*sx,width:0,size,color:color(style.color),bold:Number(style.fontWeight)>=600,italic:style.fontStyle==='italic',underline:style.textDecorationLine.includes('underline'),strike:style.textDecorationLine.includes('line-through')};
            current={rawTop:r.top,top:(r.top-origin.top)*sy,height:r.height*sy,baseline:(r.top-origin.top+baseline(style))*sy,spans:[span]};
            lines.push(current);
          }
          const span=current.spans[0];span.text+=part.text;span.width=(r.right-origin.left)*sx-span.x;
        }
      }
      for(const image of page.querySelectorAll('.flow img')) {
        const r=image.getBoundingClientRect();if(!visible(r))continue;
        const canvas=document.createElement('canvas');canvas.width=Math.round(r.width*3);canvas.height=Math.round(r.height*3);
        const ctx=canvas.getContext('2d');const style=getComputedStyle(image);
        const fit=style.objectFit;let w=canvas.width,h=canvas.height,x=0,y=0;
        if(fit==='cover'||fit==='contain') {
          const scale=(fit==='cover'?Math.max:Math.min)(w/image.naturalWidth,h/image.naturalHeight);
          w=image.naturalWidth*scale;h=image.naturalHeight*scale;x=(canvas.width-w)/2;y=(canvas.height-h)/2;
        }
        ctx.drawImage(image,x,y,w,h);
        pictures.push({data:canvas.toDataURL('image/png').split(',')[1],x:(r.left-origin.left)*sx,y:(r.top-origin.top)*sy,width:r.width*sx,height:r.height*sy});
        canvas.width=0;canvas.height=0;
      }
      output.push({lines:lines.map(({rawTop,...line})=>line),rules,pictures});
    }
    BojianPages.postMessage(JSON.stringify({type:'native-layout',token,pages:output}));
  } catch(e) {BojianPages.postMessage(JSON.stringify({type:'error',token,message:String(e.message||e)}));}
};
