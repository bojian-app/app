// Bind server-sanitized template DOM to resume fields, then paginate the DOM.
// Preview and export both use these exact pages; no PDF preview is involved.
(function () {
  const tell = value => BojianPages.postMessage(JSON.stringify(value));
  const itemKeys = new Set(['name','title','subtitle','auxiliary','start_date','end_date','date_range','detail','secondary_detail']);
  const scalar = (scope, key) => key === 'photo' ? payload.photo : scope[key] ?? (scope !== payload.fields && itemKeys.has(key) ? '' : payload.fields[key] ?? '');
  const meaningful = value => Array.isArray(value) ? value.some(meaningful) : value && typeof value === 'object' ? Object.values(value).some(meaningful) : value != null && String(value).trim() !== '';
  const conditionValue = (scope, keys) => keys.split('|').some(key => meaningful(scalar(scope, key)));
  const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const sectionOrder=['job_expectation','self_evaluation','work_experiences','projects','educations','skills','certifications'];
  const protocol=Number(payload.protocol_version||1);
  const richText=value=>value&&Array.isArray(value.blocks)?value.blocks.map(b=>(b.spans||[]).map(s=>typeof s.text==='string'?s.text:'').join('')).join('\n'):'';
  function prepareV2() {
    if(protocol!==2)return;
    const fields=payload.fields;
    fields.birth_date_label=fields.birth_date_label||'出生日期';
    for(const key of ['educations','work_experiences','projects','certifications','skills']) {
      fields[key]=(Array.isArray(fields[key])?fields[key]:[]).filter(row=>['title','name','subtitle','auxiliary','start_date','end_date','detail','secondary_detail'].some(k=>String(row[k]??'').trim()||richText(row[k+'_rich']).trim())).map(row=>{
        const copy={...row};
        for(const key of ['detail','secondary_detail']) {const rich=richText(copy[key+'_rich']);if(rich.trim())copy[key]=rich;}
        const start=String(copy.start_date||'').trim(),end=String(copy.end_date||'').trim();
        copy.date_range=start&&end&&start!==end?start+' — '+end:start||end;
        return copy;
      });
    }
    const rich=richText(fields.preference_rich);if(rich.trim())fields.preference=rich;
  }
  function renderRich(target,scope,key) {
    const raw=scope[key+'_rich'];
    if(!richText(raw).trim()&&!String(scope[key]||'').trim())return;
    const blocks=raw&&Array.isArray(raw.blocks)&&richText(raw).trim()?raw.blocks:String(scope[key]||'').split(/\r\n|\r|\n/).map(text=>({kind:'paragraph',spans:[{text}]}));
    let list=null,lastKind='',number=0;
    for(const block of blocks) {
      const kind=['bullet','numbered'].includes(block.kind)?block.kind:'paragraph';
      if(kind==='paragraph'){list=null;number=0;}
      else if(kind!==lastKind||!list){list=document.createElement(kind==='numbered'?'ol':'ul');list.style.listStyle='none';target.appendChild(list);number=0;}
      const p=document.createElement(kind==='paragraph'?'p':'li');
      if(list){const marker=document.createElement('span');marker.textContent=kind==='numbered'?`${++number}. `:'• ';marker.dataset.bjListMarker=kind;p.appendChild(marker);}
      for(const span of Array.isArray(block.spans)?block.spans:[]) {
        if(typeof span.text!=='string')continue;
        let node=document.createTextNode(span.text);
        for(const [flag,tag] of [['bold','strong'],['italic','em'],['underline','u'],['strikethrough','s']])if(span[flag]===true){const wrapper=document.createElement(tag);wrapper.appendChild(node);node=wrapper;}
        p.appendChild(node);
      }
      if(!p.childNodes.length)p.appendChild(document.createElement('br'));
      (list||target).appendChild(p);lastKind=kind;
    }
  }
  function reorderSections(flow) {
    if(protocol!==2)return;
    const nodes=new Map([...flow.querySelectorAll('[data-bj-section]')].map(n=>[n.dataset.bjSection,n]));
    const stored=Array.isArray(payload.fields.section_order)?payload.fields.section_order:[];
    const order=['personal_info',...new Set([...stored.filter(k=>sectionOrder.includes(k)),...sectionOrder])];
    const values={personal_info:['name','phone','email','birth_date','gender'].some(k=>meaningful(payload.fields[k]))||!!payload.photo,job_expectation:['position','city','industry','salary'].some(k=>meaningful(payload.fields[k])),self_evaluation:meaningful(payload.fields.preference)||!!richText(payload.fields.preference_rich).trim()};
    for(const key of order){const n=nodes.get(key);if(!n)throw Error('模板缺少模块：'+key);if(!(key in values?values[key]:meaningful(payload.fields[key]))){n.remove();continue;}n.parentElement.appendChild(n);}
  }
  function makeWordModel(flow,margins) {
    if(protocol!==2)return null;
    const clone=flow.cloneNode(true);clone.removeAttribute('id');clone.style.cssText=`position:absolute;left:-200000px;top:0;width:${794-margins.left-margins.right}px;height:auto;column-width:auto;column-count:auto;visibility:hidden;`;
    document.body.appendChild(clone);
    const sx=595.28/794,base=clone.getBoundingClientRect(),lines=[],pictures=[],rules=[];
    const owners=new Map();let id=0;
    const rgba=value=>{const a=value.match(/[\d.]+/g)?.map(Number)||[36,48,71];return ((((a[3]??1)*255)<<24)|(a[0]<<16)|(a[1]<<8)|a[2])>>>0;};
    const walker=document.createTreeWalker(clone,NodeFilter.SHOW_TEXT|NodeFilter.SHOW_ELEMENT);
    let node;
    while((node=walker.nextNode())) {
      if(node.nodeType===Node.ELEMENT_NODE&&node.tagName!=='BR')continue;
      const parent=node.parentElement;
      let owner=parent.closest('p,h1,h2,h3,h4,h5,h6,li');
      if(!owner){if(node.nodeType!==Node.TEXT_NODE||!node.nodeValue.trim())continue;owner=parent;}
      if(!clone.contains(owner))continue;
      const style=getComputedStyle(parent);if(style.display==='none'||Number(style.opacity)===0)continue;
      if(!owner.getClientRects().length)continue;
      let line=owners.get(owner);
      if(!line){
        const r=owner.getBoundingClientRect(),s=getComputedStyle(owner),size=parseFloat(s.fontSize)*sx,top=(r.top-base.top+margins.top)*sx;
        line={paragraph_id:'v2-'+(++id),paragraph_field:owner.closest('[data-bj-body]')?.dataset.bjField||null,paragraph_left:(r.left-base.left+margins.left)*sx,paragraph_width:r.width*sx,paragraph_bottom:(r.bottom-base.top+margins.top)*sx,paragraph_align_right:owner.hasAttribute('data-bj-date')||s.textAlign==='right',top,height:(parseFloat(s.lineHeight)||parseFloat(s.fontSize)*1.5)*sx,baseline:top+size,spans:[]};owners.set(owner,line);lines.push(line);
      }
      const text=node.nodeType===Node.TEXT_NODE?node.nodeValue:'\n';
      if(!text)continue;
      line.spans.push({text,x:line.paragraph_left,width:0,size:parseFloat(style.fontSize)*sx,color:rgba(style.color),weight:Number(style.fontWeight)||400,italic:style.fontStyle==='italic',underline:style.textDecorationLine.includes('underline')||!!parent.closest('u'),strike:style.textDecorationLine.includes('line-through')||!!parent.closest('s')});
    }
    for(const [imageIndex,img] of [...clone.querySelectorAll('img')].entries()) {
      const source=flow.querySelectorAll('img')[imageIndex];
      const r=img.getBoundingClientRect();if(!r.width||!r.height)continue;
      const canvas=document.createElement('canvas');canvas.width=Math.round(r.width*3);canvas.height=Math.round(r.height*3);
      const ctx=canvas.getContext('2d'),fit=getComputedStyle(img).objectFit;
      let w=canvas.width,h=canvas.height,x=0,y=0;
      if(fit==='cover'||fit==='contain'){const scale=(fit==='cover'?Math.max:Math.min)(w/source.naturalWidth,h/source.naturalHeight);w=source.naturalWidth*scale;h=source.naturalHeight*scale;x=(canvas.width-w)/2;y=(canvas.height-h)/2;}
      ctx.drawImage(source,x,y,w,h);pictures.push({data:canvas.toDataURL('image/png').split(',')[1],x:(r.left-base.left+margins.left)*sx,y:(r.top-base.top+margins.top)*sx,width:r.width*sx,height:r.height*sx});
    }
    const merged=[];
    for(const [owner,line] of owners){
      const previous=merged.at(-1);
      if(previous&&!line.paragraph_field&&!previous.line.paragraph_field&&!line.paragraph_align_right&&!previous.line.paragraph_align_right&&previous.owner.parentElement===owner.parentElement&&Math.abs(previous.line.top-line.top)<1&&line.paragraph_left>=previous.line.paragraph_left+previous.line.paragraph_width-1){
        previous.line.spans.push({...line.spans[0],text:'    '},...line.spans);
        previous.line.paragraph_width=line.paragraph_left+line.paragraph_width-previous.line.paragraph_left;
        previous.line.paragraph_bottom=Math.max(previous.line.paragraph_bottom,line.paragraph_bottom);
      }else merged.push({owner,line});
    }
    // Keep horizontal template borders in the continuous Word model too.
    // The PDF capture has its own page paint layer; Word cannot reuse that
    // fixed-page background when editable paragraphs reflow.
    for(const element of [clone,...clone.querySelectorAll('*')]) {
      const r=element.getBoundingClientRect(),style=getComputedStyle(element);
      if(r.width<=0||style.display==='none'||Number(style.opacity)===0)continue;
      for(const side of ['Top','Bottom']) {
        const thickness=parseFloat(style['border'+side+'Width']);
        const color=rgba(style['border'+side+'Color']);
        if(!thickness||!(color>>>24)||['none','hidden'].includes(style['border'+side+'Style']))continue;
        const y=side==='Top'?r.top+thickness/2:r.bottom-thickness/2;
        rules.push({x:(r.left-base.left+margins.left)*sx,y:(y-base.top+margins.top)*sx,width:r.width*sx,thickness:thickness*sx,color});
      }
    }
    clone.remove();return {lines:merged.map(entry=>entry.line),rules,pictures,margins:Object.fromEntries(Object.entries(margins).map(([k,v])=>[k,v*sx]))};
  }

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
      const conditions=[...state.text.matchAll(/\{\{(?:#if\s+|\?)([a-z_]+(?:\|[a-z_]+)*)\}\}((?:(?!\{\{(?:#if\s|\?))[\s\S])*?)\{\{\/if\}\}/g)].reverse();
      if (!conditions.length) break;
      for (const token of conditions) {
        const start=token.index,end=start+token[0].length;
        if (conditionValue(scope,token[1])) {
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
  function bind(parent, scope, scopeId = "root") {
    let index = 0;
    while (index < parent.children.length) {
      const child = parent.children[index], text = child.textContent.trim();
      if(protocol===2 && child.hasAttribute('data-bj-body'))child.dataset.bjField=scopeId==='root'?'self_evaluation.body':scopeId+'.body';
      if(protocol===2 && child.hasAttribute('data-bj-rich')){renderRich(child,scope,child.dataset.bjRich);index++;continue;}
      if(protocol===2 && /\{\{\s*date_range\s*\}\}/.test(text) && child.matches('p'))child.dataset.bjDate='true';
      const loop = text.match(/^\{\{#([a-z_]+)\}\}$/);
      const condition = text.match(/^\{\{(?:#if\s+|\?)([a-z_]+(?:\|[a-z_]+)*)\}\}$/);
      if (loop || condition) {
        const key = (loop || condition)[1], close = condition ? '{{/if}}' : '{{/'+key+'}}';
        let end = index+1, depth = 1;
        for (; end < parent.children.length; end++) {
          const next = parent.children[end].textContent.trim();
          if (condition && /^\{\{(?:#if\s+|\?)[a-z_]+(?:\|[a-z_]+)*\}\}$/.test(next)) depth++;
          if (next === close && --depth === 0) break;
          // A loop has no nested loops; only matching endings affect depth.
          if (next !== close && !(condition && /^\{\{(?:#if\s+|\?)[a-z_]+(?:\|[a-z_]+)*\}\}$/.test(next))) depth = Math.max(1,depth);
        }
        if (end >= parent.children.length) throw new Error('模板循环或条件格式不完整');
        const originals = Array.from(parent.children).slice(index+1,end);
        const values = loop ? (scalar(scope,key) || []) : (conditionValue(scope,key) ? [scope] : []);
        if (!Array.isArray(values)) throw new Error('模板循环字段无效');
        const fragment = document.createDocumentFragment();
        if (values.length > 100) throw new Error('模板条目过多');
        for (const [entryIndex,value] of values.filter(meaningful).entries()) {
          const holder = document.createElement('div');
          originals.forEach(item => holder.appendChild(item.cloneNode(true)));
          bind(holder, value, loop?key+'.'+entryIndex:scopeId);
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
      else bind(child,scope,scopeId);
      index++;
    }
  }
  async function start(notifyReady = true, prepareWordModel = false) {
    const started=performance.now();
    const timing=stage=>{if(window.bojianTrace)tell({type:'timing',stage,elapsed_ms:Math.round(performance.now()-started)});};
    let flow = document.getElementById('flow');
    if (!flow) { flow = document.createElement('div'); flow.id = 'flow'; document.body.appendChild(flow); }
    flow.innerHTML = payload.html;
    flow.querySelectorAll('script,iframe,object,embed,form,link,style').forEach(n=>n.remove());
    flow.querySelectorAll('*').forEach(n=>Array.from(n.attributes).forEach(a=>{ if (/^on/i.test(a.name)) n.removeAttribute(a.name); }));
    if(protocol!==1 && protocol!==2)throw Error("模板协议不受支持，请升级 APP");
    prepareV2();
    reorderSections(flow);
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
    if (/\{\{|\}\}/.test(flow.textContent)) throw new Error('模板占位结构暂不支持');
    timing('dom-bound');
    await document.fonts.ready;
    timing('fonts-ready');
    await Promise.all(Array.from(flow.querySelectorAll('img')).map(image=>new Promise((resolve,reject)=>{
      if (image.complete) return image.naturalWidth ? resolve() : reject(new Error('模板图片不可用'));
      image.onload = resolve; image.onerror = ()=>reject(new Error('模板图片不可用'));
      setTimeout(()=>reject(new Error('模板图片加载超时')),15000);
    })));
    const count = Math.max(1, Math.ceil((flow.scrollWidth+1)/(width+32)));
    timing('images-ready');
    // Editable Word geometry and image encoding are only needed for export.
    window.bojianWordModel=prepareWordModel?makeWordModel(flow,margins):null;
    if (count > 30) throw new Error('模板页数过多');
    const pages = document.getElementById('pages');
    pages.replaceChildren();
    for (let i=0;i<count;i++) {
      const page = document.createElement('div'); page.className='paper';
      const inner = document.createElement('div'); inner.className='inner';
      Object.assign(inner.style,{left:margins.left+'px',top:margins.top+'px',width:width+'px',height:height+'px'});
      const clone = flow.cloneNode(true); clone.removeAttribute('id'); clone.className='flow';
      clone.style.left = -(width+32)*i+'px'; inner.appendChild(clone); page.appendChild(inner); pages.appendChild(page);
    }
    flow.remove();
    window.pageCount = count;
    timing('pages-ready');
    if (notifyReady) tell({type:'ready',count});
    return count;
  }
  // Export is re-typeset with its embedded font; preview uses the device font.
  // Re-pagination keeps export geometry aligned with the font in PDF/Word.
  window.setResumeExportMode = async function(enabled, token) {
    try {
      if (enabled) document.documentElement.style.setProperty('--resume-font', "'ResumeDocument',sans-serif");
      else document.documentElement.style.removeProperty('--resume-font');
      const count = await start(false, enabled);
      tell({type:'font-ready',token,count});
    } catch(e) { tell({type:'error',token,message:String(e.message||e)}); }
  };
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
    function rotation(element) {
      let angle=0;
      for(let n=element;n && !n.classList.contains('flow');n=n.parentElement) {
        const transform=getComputedStyle(n).transform;
        if(transform!=='none') {
          const matrix=new DOMMatrixReadOnly(transform);
          angle+=Math.atan2(matrix.b,matrix.a)*180/Math.PI;
        }
      }
      const normalized=(Math.round(angle)%360+360)%360;
      return normalized===90||normalized===270?normalized:0;
    }
    const output=[];
    const pages=Array.from(document.querySelectorAll('.paper'));
    for(const [pageIndex,page] of pages.entries()) {
      const origin=page.getBoundingClientRect(), clip=page.querySelector('.inner').getBoundingClientRect();
      // Preserve CSS textures, SVG ornaments, gradients and rounded backgrounds
      // from the exact preview DOM. This paint layer contains no resume text or
      // photos; those remain native editable text and separate image objects.
      const paint=await html2canvas(page,{
        scale:2,backgroundColor:'#ffffff',logging:false,useCORS:false,allowTaint:false,
        onclone:doc=>{
          const target=doc.querySelectorAll('.paper')[pageIndex];
          const nodes=[target,...target.querySelectorAll('*')],pseudoRules=[];
          for(const [index,element] of nodes.entries()) {
            element.setAttribute('data-export-paint',String(index));
            // Resolve currentColor before hiding glyphs, keeping their borders.
            const style=doc.defaultView.getComputedStyle(element);
            const borders=['top','right','bottom','left'].map(side=>
              [side,style.getPropertyValue('border-'+side+'-color')]);
            for(const [side,value] of borders)element.style.setProperty('border-'+side+'-color',value,'important');
            for(const pseudo of ['::before','::after']) {
              const ps=doc.defaultView.getComputedStyle(element,pseudo);
              if(ps.content==='none'||ps.content==='normal')continue;
              const border=['top','right','bottom','left'].map(side=>
                'border-'+side+'-color:'+ps.getPropertyValue('border-'+side+'-color')+'!important').join(';');
              pseudoRules.push('[data-export-paint="'+index+'"]'+pseudo+'{'+border+';color:transparent!important;text-shadow:none!important;text-decoration-color:transparent!important}');
            }
          }
          const css=doc.createElement('style');
          css.textContent='[data-export-paint]{color:transparent!important;text-shadow:none!important;text-decoration-color:transparent!important}img[data-export-paint]{visibility:hidden!important}'+pseudoRules.join('');
          doc.head.appendChild(css);
        }
      });
      const background=paint.toDataURL('image/png').split(',')[1];
      paint.width=0;paint.height=0;
      const visible=r=>r.width>0 && r.height>0 && r.left>=clip.left-.5 && r.right<=clip.right+.5 && r.bottom>clip.top+.5 && r.top<clip.bottom-.5;
      const lines=[],rules=[],pictures=[];
      // Templates may put per-page frames on .paper and its pseudo-elements,
      // outside the flowing text columns. Preserve those fills and borders too.
      function furniture(style,x,y,width,height) {
        const background=color(style.backgroundColor);
        if(background>>>24)rules.push({x:x*sx,y:y*sy,width:width*sx,height:height*sy,thickness:0,color:background});
        for(const side of ['Top','Bottom','Left','Right']) {
          const thickness=parseFloat(style['border'+side+'Width']);
          if(!thickness||style['border'+side+'Style']==='none')continue;
          const horizontal=side==='Top'||side==='Bottom';
          rules.push({x:(x+(side==='Right'?width-thickness:0))*sx,y:(y+(side==='Bottom'?height-thickness:0))*sy,width:(horizontal?width:thickness)*sx,height:(horizontal?thickness:height)*sy,thickness:0,color:color(style['border'+side+'Color'])});
        }
      }
      furniture(getComputedStyle(page),0,0,origin.width,origin.height);
      for(const pseudo of ['::before','::after']) {
        const style=getComputedStyle(page,pseudo);
        if(style.content==='none'||style.content==='normal'||style.display==='none')continue;
        const x=parseFloat(style.left)||0,y=parseFloat(style.top)||0;
        let width=parseFloat(style.width),height=parseFloat(style.height);
        if(!Number.isFinite(width))width=origin.width-x-(parseFloat(style.right)||0);
        if(!Number.isFinite(height))height=origin.height-y-(parseFloat(style.bottom)||0);
        if(style.boxSizing!=='border-box') {
          width+=['Left','Right'].reduce((v,side)=>v+(parseFloat(style['padding'+side])||0)+(parseFloat(style['border'+side+'Width'])||0),0);
          height+=['Top','Bottom'].reduce((v,side)=>v+(parseFloat(style['padding'+side])||0)+(parseFloat(style['border'+side+'Width'])||0),0);
        }
        if(width>0&&height>0)furniture(style,x,y,width,height);
      }
      for(const node of page.querySelectorAll('.flow *')) {
        const style=getComputedStyle(node);
        if(style.display==='none'||style.visibility==='hidden'||Number(style.opacity)===0)continue;
        for(const r of node.getClientRects()) {
          const left=Math.max(r.left,clip.left),right=Math.min(r.right,clip.right);
          const top=Math.max(r.top,clip.top),bottom=Math.min(r.bottom,clip.bottom);
          if(right<=left||bottom<=top)continue;
          const background=color(style.backgroundColor);
          if(background>>>24)rules.push({x:(left-origin.left)*sx,y:(top-origin.top)*sy,width:(right-left)*sx,height:(bottom-top)*sy,thickness:0,color:background});
          for(const side of ['Top','Bottom']) {
            const thickness=parseFloat(style['border'+side+'Width']);
            const y=side==='Top'?r.top:r.bottom;
            if(thickness && y>=clip.top && y<=clip.bottom && style['border'+side+'Style']!=='none')rules.push({x:(left-origin.left)*sx,y:(y-origin.top)*sy,width:(right-left)*sx,height:0,thickness:thickness*sy,color:color(style['border'+side+'Color'])});
          }
          for(const side of ['Left','Right']) {
            const thickness=parseFloat(style['border'+side+'Width']);
            const x=side==='Left'?r.left:r.right;
            if(thickness && x>=clip.left && x<=clip.right && style['border'+side+'Style']!=='none')rules.push({x:(x-origin.left)*sx,y:(top-origin.top)*sy,width:thickness*sx,height:(bottom-top)*sy,thickness:0,color:color(style['border'+side+'Color'])});
          }
        }
      }
      const paragraphIds=new WeakMap(),paragraphBreaks=new WeakMap();
      let nextParagraphId=0;
      function paragraphOwner(element) {
        for(let n=element;n && n!==page;n=n.parentElement) {
          const display=getComputedStyle(n).display;
          const parentDisplay=n.parentElement?getComputedStyle(n.parentElement).display:'';
          if(['block','list-item','table-cell','inline-block','flex','grid'].includes(display) || ['flex','inline-flex','grid','inline-grid'].includes(parentDisplay))return n;
        }
        return page.querySelector('.flow');
      }
      function paragraphMetadata(owner) {
        if(!paragraphIds.has(owner))paragraphIds.set(owner,++nextParagraphId);
        const r=owner.getBoundingClientRect(),s=getComputedStyle(owner);
        const left=Math.max(clip.left,r.left+(parseFloat(s.paddingLeft)||0)+(parseFloat(s.borderLeftWidth)||0));
        const right=Math.min(clip.right,r.right-(parseFloat(s.paddingRight)||0)-(parseFloat(s.borderRightWidth)||0));
        return {paragraph_id:`html-${paragraphIds.get(owner)}-${paragraphBreaks.get(owner)||0}`,paragraph_left:(left-origin.left)*sx,paragraph_width:Math.max(1,(right-left)*sx)};
      }
      const walker=document.createTreeWalker(page.querySelector('.flow'),NodeFilter.SHOW_TEXT|NodeFilter.SHOW_ELEMENT);
      let node;
      while((node=walker.nextNode())) {
        const parent=node.parentElement;
        if(node.nodeType===Node.ELEMENT_NODE) {
          if(node.tagName==='BR') {
            const owner=paragraphOwner(parent);
            paragraphBreaks.set(owner,(paragraphBreaks.get(owner)||0)+1);
          }
          continue;
        }
        const style=getComputedStyle(parent),owner=paragraphOwner(parent);
        if(style.display==='none'||style.visibility==='hidden'||!node.nodeValue)continue;
        const angle=rotation(parent);
        const segments=typeof Intl.Segmenter==='function'?[...new Intl.Segmenter('zh',{granularity:'grapheme'}).segment(node.nodeValue)].map(s=>({text:s.segment,index:s.index})):Array.from(node.nodeValue).map((text,i,a)=>({text,index:a.slice(0,i).join('').length}));
        if(angle) {
          // Rotated decorative lettering may be cropped by a ribbon or page.
          // Keep that decoration as a small picture; resume body text remains
          // native/editable, with no full-page screenshot in either format.
          const range=document.createRange();range.selectNodeContents(node);
          const bounds=range.getBoundingClientRect();
          let left=Math.max(bounds.left,clip.left),right=Math.min(bounds.right,clip.right);
          let top=Math.max(bounds.top,clip.top),bottom=Math.min(bounds.bottom,clip.bottom);
          for(let n=parent;n && n!==page;n=n.parentElement) {
            const s=getComputedStyle(n),r=n.getBoundingClientRect();
            if(['hidden','clip','scroll','auto'].includes(s.overflowX)){left=Math.max(left,r.left);right=Math.min(right,r.right);}
            if(['hidden','clip','scroll','auto'].includes(s.overflowY)){top=Math.max(top,r.top);bottom=Math.min(bottom,r.bottom);}
          }
          if(right>left && bottom>top) {
            const canvas=document.createElement('canvas');canvas.width=Math.ceil((right-left)*3);canvas.height=Math.ceil((bottom-top)*3);
            const ctx=canvas.getContext('2d');ctx.scale(3,3);ctx.font=style.font;ctx.fillStyle=style.color;
            for(const part of segments) {
              range.setStart(node,part.index);range.setEnd(node,part.index+part.text.length);
              const r=range.getBoundingClientRect(),b=baseline(style);
              ctx.save();
              ctx.translate((angle===90?r.right-b:r.left+b)-left,(angle===90?r.top:r.bottom)-top);
              ctx.rotate(angle*Math.PI/180);ctx.fillText(part.text,0,0);ctx.restore();
            }
            pictures.push({data:canvas.toDataURL('image/png').split(',')[1],x:(left-origin.left)*sx,y:(top-origin.top)*sy,width:(right-left)*sx,height:(bottom-top)*sy});
            canvas.width=0;canvas.height=0;
          }
          continue;
        }
        let current=null;
        for(const part of segments) {
          const range=document.createRange();range.setStart(node,part.index);range.setEnd(node,part.index+part.text.length);
          const r=range.getBoundingClientRect();
          const newline=/[\r\n]/.test(part.text);
          if(newline && ['pre','pre-wrap','pre-line','break-spaces'].includes(style.whiteSpace)) {
            paragraphBreaks.set(owner,(paragraphBreaks.get(owner)||0)+1);
            current=null;continue;
          }
          if(!visible(r)) {
            // A soft-wrap space often has zero width in the DOM range. Keep
            // it for Word paragraph editing without changing PDF paint widths.
            const previous=current||lines[lines.length-1];
            if(/^[\s]+$/.test(part.text) && r.width===0 && r.top>=clip.top-.5 && r.top<clip.bottom && previous?.paragraph_id===paragraphMetadata(owner).paragraph_id) {
              const span=previous.spans[previous.spans.length-1];
              const value=span.word_text??span.text;
              if(!/[\s]$/.test(value))span.word_text=value+' ';
            }
            current=null;continue;
          }
          if(!current||Math.abs(current.rawTop-r.top)>.5) {
            const size=parseFloat(style.fontSize)*sx;
            const span={text:'',x:(r.left-origin.left)*sx,width:0,size,color:color(style.color),weight:Number(style.fontWeight)||400,bold:Number(style.fontWeight)>=600,italic:style.fontStyle==='italic',underline:style.textDecorationLine.includes('underline'),strike:style.textDecorationLine.includes('line-through')};
            current={...paragraphMetadata(owner),rawTop:r.top,top:(r.top-origin.top)*sy,height:r.height*sy,baseline:(r.top-origin.top+baseline(style))*sy,spans:[span]};
            lines.push(current);
          }
          const span=current.spans[0];const value=newline?' ':part.text;span.text+=value;if(span.word_text!==undefined)span.word_text+=value;span.width=(r.right-origin.left)*sx-span.x;
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
      output.push({lines:lines.map(({rawTop,...line})=>line),rules,pictures,background});
    }
    BojianPages.postMessage(JSON.stringify({type:'native-layout',token,pages:output,word_model:window.bojianWordModel}));
  } catch(e) {BojianPages.postMessage(JSON.stringify({type:'error',token,message:String(e.message||e)}));}
};
