let result = null;
let serviceReady = false;
const api = 'http://127.0.0.1:8766';
const $ = id => document.getElementById(id);
const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const exportButton = document.querySelector('button[onclick="exportRedacted()"]');
if (exportButton && !document.querySelector('#mappingButton')) { const b=document.createElement('button'); b.id='mappingButton'; b.textContent='导出加密映射'; b.onclick=exportMapping; exportButton.parentNode.appendChild(b); }
const progressPanel=document.createElement('div'); progressPanel.id='progressPanel'; progressPanel.style.cssText='margin:8px 24px;padding:8px 12px;background:#eef3f8;border-radius:6px;font-size:13px;color:#536071'; progressPanel.innerHTML='<div id="progressLabel">等待操作</div><div style="height:6px;background:#d8e0ea;border-radius:4px;margin-top:6px"><div id="progressBar" style="height:6px;width:0%;background:#1769d2;border-radius:4px;transition:width .3s"></div></div>'; document.querySelector('header')?.after(progressPanel);
function setProgress(label, percent) { const labelEl=document.querySelector('#progressLabel'), bar=document.querySelector('#progressBar'); if(labelEl) labelEl.textContent=label; if(bar) bar.style.width=`${percent}%`; }
const highlightStyle=document.createElement('style'); highlightStyle.textContent='.entity-mark{padding:1px 2px;border-radius:3px;cursor:pointer;box-shadow:inset 0 -2px 0 rgba(0,0,0,.12)}.entity-mark:hover{outline:2px solid #1769d2}.mark-PERSON,.mark-PLAINTIFF,.mark-DEFENDANT,.mark-APPLICANT,.mark-RESPONDENT,.mark-ATTORNEY,.mark-LEGAL_REPRESENTATIVE{background:#fff09a}.mark-ORGANIZATION,.mark-COURT,.mark-LAW_FIRM{background:#b9dcff}.mark-ADDRESS{background:#bcecc9}.mark-DEPARTMENT,.mark-PROJECT{background:#e4d1ff}.mark-PHONE,.mark-EMAIL{background:#e2c6ff}.mark-ID_NUMBER,.mark-BANK_CARD{background:#ffb9b9}.mark-CASE_NUMBER,.mark-CONTRACT_NUMBER{background:#ffd7a3}'; document.head.appendChild(highlightStyle);
function renderText() { if (!result) return; const list=result.entities.map((e,i)=>({...e,_i:i})).filter(e=>Number.isInteger(e.start)&&Number.isInteger(e.end)&&e.start>=0&&e.end>e.start).sort((a,b)=>a.start-b.start||b.end-a.end); let html='',cursor=0; for (const e of list) { if(e.start<cursor) continue; html+=esc(result.text.slice(cursor,e.start)); html+=`<mark class="entity-mark mark-${esc(e.type)}" title="${esc(e.type)} · ${esc(e.value)}" data-entity-index="${e._i}">${esc(result.text.slice(e.start,e.end))}</mark>`; cursor=e.end; } html+=esc(result.text.slice(cursor)); $('content').innerHTML=html; document.querySelectorAll('.entity-mark').forEach(mark=>mark.addEventListener('click',()=>{const card=document.querySelector('#e'+mark.dataset.entityIndex); card?.scrollIntoView({behavior:'smooth',block:'center'});})); }
async function analyze(file) {
  if (!serviceReady) { $('status').textContent=' 本地服务尚未连接，请稍候…'; return; }
  const input=$('file'); input.disabled=true; $('status').textContent = ' 正在上传文件…'; setProgress(`正在上传：${file.name}`,10);
  const requestId = (crypto.randomUUID ? crypto.randomUUID() : Date.now().toString(36));
  console.info('[LegalRedaction]', 'analyze_start', {requestId, name:file.name, size:file.size, type:file.type});
  let phaseTimer;
  try {
    const bytes = new Uint8Array(await file.arrayBuffer());
    let binary = ''; for (const byte of bytes) binary += String.fromCharCode(byte);
    $('status').textContent = ' 正在提取文本…'; setProgress('正在提取文本…',30);
    phaseTimer=setTimeout(()=>{ $('status').textContent=' 模型识别中，预计需要几十秒…'; setProgress('模型识别中（可能需要几十秒）…',70); },1500);
    const controller=new AbortController(); const timeout=setTimeout(()=>controller.abort(),600000);
    let response; try { response=await fetch(api + '/analyze-upload', {method:'POST', headers:{'Content-Type':'application/json','X-Request-ID':requestId}, body:JSON.stringify({name:file.name, data:btoa(binary)}), signal:controller.signal}); } finally { clearTimeout(timeout); }
    const responseId = response.headers.get('X-Request-ID') || requestId;
    if (!response.ok) { const detail=await response.text(); console.error('[LegalRedaction]', 'analyze_error', {requestId:responseId,status:response.status,detail}); throw new Error(`请求失败（HTTP ${response.status}，ID ${responseId}）：${detail}`); }
    result = await response.json(); $('fileName').textContent = result.name; renderText(); render(); $('status').textContent = ` 识别完成：${result.entities.length} 个候选，请确认底色标记后导出`; setProgress(`识别完成：${result.entities.length} 个候选，等待人工确认`,100);
    console.info('[LegalRedaction]', 'analyze_done', {requestId:responseId, chars:result.text.length, entities:result.entities.length});
  } catch(error) {
    const detail=error.name==='AbortError' ? `模型处理超过 10 分钟（请求 ID ${requestId}）。文件过长或分块过多，请查看后端日志。` : (error.message==='Load failed' ? `无法连接本地服务（请求 ID ${requestId}）。请确认 Tauri 已完整重启，并检查 8766 端口。` : error.message);
    console.error('[LegalRedaction]', 'ui_error', {requestId,error}); $('status').textContent=' 识别失败：'+detail; setProgress(`失败：${detail}`,0); throw error;
  } finally { clearTimeout(phaseTimer); input.disabled=!serviceReady; }
}
function overlaps(e, i) { return result.entities.some((x,j) => j !== i && x.review === 'confirmed' && e.start < x.end && e.end > x.start); }
function render() {
  const types=['PERSON','ORGANIZATION','ADDRESS','DEPARTMENT','PROJECT','COURT','LAW_FIRM','PLAINTIFF','DEFENDANT','APPLICANT','RESPONDENT','ATTORNEY','LEGAL_REPRESENTATIVE','PHONE','ID_NUMBER','BANK_CARD','EMAIL','CASE_NUMBER','CONTRACT_NUMBER'];
  $('entities').innerHTML = result.entities.map((e,i) => `<div class="entity ${e.review === 'confirmed' ? 'ok' : 'no'} ${overlaps(e,i) ? 'overlap' : ''}" id="e${i}"><b>${esc(e.type)}</b> · ${e.start}:${e.end} · ${esc(e.policy||'manual_review')}${overlaps(e,i) ? ' · 重叠' : ''}<br><input type="text" value="${esc(e.value)}" onchange="editEntity(${i},'value',this.value)"><select onchange="editEntity(${i},'type',this.value)">${types.map(t=>`<option ${e.type===t?'selected':''}>${t}</option>`).join('')}</select><br><button onclick="review(${i},true)">确认</button><button onclick="review(${i},false)">忽略</button></div>`).join('');
}
function editEntity(i, key, value) { const e=result.entities[i]; if (key==='value') { const start=result.text.indexOf(value, e.start); if (start >= 0 && start <= e.end) { e.start=start; e.end=start+value.length; } } e[key]=value; renderText(); render(); }
function review(i, confirmed) { const e=result.entities[i]; if (confirmed && overlaps(e,i)) { $('status').textContent=' 无法确认：该实体与已确认实体重叠'; return; } e.review = confirmed ? 'confirmed' : 'rejected'; renderText(); render(); }
function download(name, data, type='text/plain;charset=utf-8') { const a=document.createElement('a'); a.href=URL.createObjectURL(new Blob([data],{type})); a.download=name; a.click(); setTimeout(()=>URL.revokeObjectURL(a.href),1000); }
function exportRedacted() { if (!result) return; const confirmed = result.entities.filter(e => e.review === 'confirmed').sort((a,b)=>a.start-b.start); if (!confirmed.length) { $('status').textContent=' 尚未确认任何实体，请先点击候选中的“确认”'; return; } let out='', cursor=0, mapping={}; confirmed.forEach((e,i)=>{ if(e.start<cursor) return; const token=`<${e.type}_${String(i+1).padStart(3,'0')}>`; out += result.text.slice(cursor,e.start)+token; mapping[token]={type:e.type,value:e.value,start:e.start,end:e.end}; cursor=e.end; }); out += result.text.slice(cursor); download((result.name||'redacted')+'.redacted.txt',out); window.lastMapping=mapping; $('status').textContent=` 已导出脱敏文本（${Object.keys(mapping).length} 个 Token）；可继续导出加密映射表`; setProgress('脱敏文本已导出',100); }
async function getKey() { const stored=localStorage.getItem('legalredaction-key'); if(stored) return crypto.subtle.importKey('raw',Uint8Array.from(atob(stored),c=>c.charCodeAt(0)),{name:'AES-GCM'},false,['encrypt','decrypt']); const key=await crypto.subtle.generateKey({name:'AES-GCM',length:256},true,['encrypt','decrypt']); const raw=new Uint8Array(await crypto.subtle.exportKey('raw',key)); localStorage.setItem('legalredaction-key',btoa(String.fromCharCode(...raw))); return key; }
async function exportMapping() { if(!window.lastMapping) { $('status').textContent=' 请先导出脱敏文本'; return; } const iv=crypto.getRandomValues(new Uint8Array(12)); const encrypted=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},await getKey(),new TextEncoder().encode(JSON.stringify(window.lastMapping)))); download((result.name||'redacted')+'.mapping.enc.json',JSON.stringify({version:1,algorithm:'AES-256-GCM',iv:Array.from(iv),ciphertext:Array.from(encrypted)},null,2),'application/json'); $('status').textContent=' 已导出加密映射表'; }
$('file').addEventListener('change', async event => { const file=event.target.files[0]; if (!file) return; $('fileName').textContent='选择中…'; try { await analyze(file); } catch (_) {} });
async function checkHealth() {
  try {
    const response=await fetch(api+'/health',{cache:'no-store'}); if (!response.ok) throw Error(`HTTP ${response.status}`);
    serviceReady=true; $('file').disabled=false; if (!result) $('status').textContent=' 本地服务已连接'; return true;
  } catch (_) {
    serviceReady=false; $('file').disabled=true; if (!result) $('status').textContent=' 正在连接本地服务…'; return false;
  }
}
checkHealth(); setInterval(checkHealth,2000);
Object.assign(window,{exportRedacted,exportMapping,review,editEntity});
