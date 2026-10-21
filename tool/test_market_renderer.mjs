// Run with PLAYWRIGHT_MODULE pointing to an installed playwright index.mjs.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const renderer = await readFile(new URL('../assets/templates/market_renderer.js', import.meta.url), 'utf8');
const browser = await chromium.launch({headless:true, ...(process.env.CHROMIUM_PATH ? {executablePath:process.env.CHROMIUM_PATH} : {})});
const page = await browser.newPage();
async function render(html, fields) {
 await page.setContent('<style>#flow,.flow{position:absolute;height:1000px;column-width:671px;column-gap:32px;column-fill:auto}#flow{left:-100000px}.paper{width:794px;height:1123px;position:relative;overflow:hidden}.inner{position:absolute;overflow:hidden}</style><div id="flow"></div><div id="pages"></div>');
 await page.evaluate(({html,fields})=>{window.payload={html,fields,photo:''};window.result=null;window.BojianPages={postMessage:s=>window.result=JSON.parse(s)}},{html,fields});
 await page.addScriptTag({content:renderer});
 await page.waitForFunction(()=>window.result);
 return page.evaluate(()=>({...window.result,text:document.querySelector('#pages').textContent}));
}
try {
 for(const syntax of ['?','#if ']) {
  const markup=`<p>{{${syntax}phone|email}}联系：{{phone}}{{email}}{{/if}}</p>`;
  assert.equal((await render(markup,{email:'a@example.com'})).text,'联系：a@example.com');
  assert.equal((await render(markup,{phone:' ',email:''})).text,'');
 }
 assert.equal((await render('<p>{{#if phone}}</p><p>{{#if email}}邮箱{{email}}{{/if}}</p><p>{{/if}}</p>',{phone:'1',email:'2'})).text,'邮箱2');
 const loop='<p>{{?skills}}</p><h2>技能</h2><p>{{#skills}}</p><p>{{name}}{{#if detail}}：{{detail}}{{/if}}</p><p>{{/skills}}</p><p>{{/if}}</p>';
 for(const fields of [{},{skills:[]},{skills:[{}]},{skills:[{name:'  '}]}]) {
  const result=await render(loop,fields);assert.equal(result.type,'ready');assert.equal(result.text,'');
 }
 assert.equal((await render(loop,{name:'本人姓名',skills:[{detail:'条目描述'}]})).text,'技能：条目描述');
 assert.equal((await render('<p>{{#skills}}</p><p>{{phone}}:{{name}}</p><p>{{/skills}}</p>',{phone:'138',name:'本人',skills:[{detail:'条目'}]})).text,'138:');
 const missing=await render('<p>{{#projects}}</p><p>{{title}}</p><p>{{/projects}}</p>',{});
 assert.equal(missing.type,'ready');assert.equal(missing.text,'');
 assert.equal((await render('<p>{{#projects}}</p><p>{{title}}</p>',{})).type,'error');
 assert.equal((await render('<p>{{?phone}}{{name}}</p>',{name:'测试'})).type,'error');
 assert.equal((await render('<p>{{#if phone}}外{{#if email}}内{{/if}}{{/if}}</p>',{phone:'1',email:'2'})).text,'外内');
 const long=await render('<p>{{#projects}}</p><p>{{title}}</p><p>{{detail}}</p><p>{{/projects}}</p>',{projects:Array.from({length:20},(_,i)=>({title:'项目'+i,detail:'真实项目描述与成果。'.repeat(100)}))});
 assert.equal(long.type,'ready');assert.ok(long.count>1);assert.ok(long.text.includes('项目19'));
 console.log('PASS: aliases, OR, nested conditions, empty/missing collections, item scope, invalid structure, multipage');
} finally {await browser.close()}
