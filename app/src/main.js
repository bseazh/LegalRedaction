let result = null;
const api = 'http://127.0.0.1:8766';
const $ = id => document.getElementById(id);
const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function analyze(path) {
  $('status').textContent = ' 正在本地识别…';
  const response = await fetch(api + '/analyze', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({path})});
  if (!response.ok) throw new Error(await response.text());
  result = await response.json(); $('fileName').textContent = result.name; $('content').textContent = result.text; render(); $('status').textContent = ` 已识别 ${result.entities.length} 个候选`;
}
function render() { $('entities').innerHTML = result.entities.map((e,i) => `<div class="entity ${e.review === 'confirmed' ? 'ok' : 'no'}" id="e${i}"><b>${esc(e.type)}</b> · ${e.start}:${e.end}<br>${esc(e.value)}<br><button onclick="review(${i},true)">确认</button><button onclick="review(${i},false)">忽略</button></div>`).join(''); }
function review(i, confirmed) { result.entities[i].review = confirmed ? 'confirmed' : 'rejected'; render(); }
function exportRedacted() { if (!result) return; const confirmed = result.entities.filter(e => e.review === 'confirmed').sort((a,b)=>a.start-b.start); let out='', cursor=0, mapping={}; confirmed.forEach((e,i)=>{const token=`<${e.type}_${String(i+1).padStart(3,'0')}>`; out += result.text.slice(cursor,e.start)+token; mapping[token]={type:e.type,value:e.value}; cursor=e.end;}); out += result.text.slice(cursor); const blob=new Blob([out+'\n\n--- local mapping ---\n'+JSON.stringify(mapping,null,2)],{type:'text/plain;charset=utf-8'}); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download=(result.name||'redacted')+'.redacted.txt'; a.click(); URL.revokeObjectURL(a.href); }
$('file').addEventListener('change', async event => { const file=event.target.files[0]; if (!file) return; $('fileName').textContent='选择中…'; try { await analyze(file.path || file.name); } catch (error) { $('status').textContent=' 识别失败：'+error.message; } });
fetch(api+'/health').then(()=>{$('status').textContent=' 本地服务已连接'}).catch(()=>{});

