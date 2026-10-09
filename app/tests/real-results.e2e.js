import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {mkdir, readFile, writeFile} from 'node:fs/promises';
import {extname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright-core';

const appRoot = fileURLToPath(new URL('../dist/', import.meta.url));
const projectRoot = fileURLToPath(new URL('../../', import.meta.url));
const reportRoot = join(projectRoot, 'reports/real-backend-regression-fallback');
const afterFixRoot = join(projectRoot, 'reports/real-backend-regression-after-fix');
const screenshotRoot = join(reportRoot, 'frontend');
const mime = {'.html':'text/html','.js':'text/javascript','.css':'text/css'};
const samples = [
  {id:'docx_legal_roles', file:join(afterFixRoot,'results/docx_legal_roles.json'), expected:14},
  {id:'pdf_registration', file:join(afterFixRoot,'results/pdf_registration.json'), expected:12},
  {id:'docx_long_recording', file:join(reportRoot,'results/docx_long_recording.json'), expected:893}
];

const results = new Map();
for (const sample of samples) results.set(sample.id, JSON.parse(await readFile(sample.file, 'utf8')));
await mkdir(screenshotRoot, {recursive:true});

const server = createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url, 'http://localhost').pathname;
    const path = join(appRoot, pathname === '/' ? 'index.html' : pathname);
    response.writeHead(200, {'Content-Type':mime[extname(path)] || 'application/octet-stream'});
    response.end(await readFile(path));
  } catch {
    response.writeHead(404).end('not found');
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));

const jobs = new Map();
const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const page = await browser.newPage({viewport:{width:1440,height:900}});
await page.route('http://127.0.0.1:8766/**', async route => {
  const url = new URL(route.request().url());
  if (url.pathname === '/health') return route.fulfill({json:{ok:true}});
  if (url.pathname === '/analyze-upload') {
    const body = JSON.parse(route.request().postData());
    const id = route.request().headers()['x-request-id'];
    jobs.set(id, body.name);
    return route.fulfill({status:202,json:{job_id:id,status:'queued'}});
  }
  const id = decodeURIComponent(url.pathname.split('/').at(-1));
  const sampleId = jobs.get(id);
  return route.fulfill({json:{status:'done',phase:'done',progress:100,result:results.get(sampleId)}});
});

const metrics = [];
try {
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  await page.locator('#status').filter({hasText:'本地服务已连接'}).waitFor();
  for (const sample of samples) {
    const started = performance.now();
    await page.locator('#file').setInputFiles({name:sample.id,mimeType:'application/octet-stream',buffer:Buffer.from(sample.id)});
    await page.locator('#reviewSummary').filter({hasText:`共 ${sample.expected} 个`}).waitFor({timeout:30000});
    const candidates = await page.locator('.entity').count();
    const highlights = await page.locator('.entity-mark').count();
    assert.equal(candidates, sample.expected, `${sample.id}: all real candidates render`);
    assert.equal(highlights > 0, true, `${sample.id}: source highlights render`);
    assert.equal(await page.locator('#exportText').isDisabled(), true, `${sample.id}: export initially blocked`);
    if (await page.locator('#confirmRequired').isEnabled()) await page.locator('#confirmRequired').click();
    while (await page.locator('.entity.pending').count()) await page.locator('.entity.pending').first().locator('[data-review="reject"]').click();
    await page.locator('.tab[data-view="preview"]').click();
    await page.locator('#previewApproved').check();
    assert.equal(await page.locator('#exportText').isEnabled(), true, `${sample.id}: export enabled after full review`);
    const preview = await page.locator('#preview').textContent();
    assert.equal(preview.includes('<PERSON_001>') || preview.includes('<LEGAL_REPRESENTATIVE_001>'), true, `${sample.id}: redacted preview contains tokens`);
    await page.screenshot({path:join(screenshotRoot, `${sample.id}.png`)});
    metrics.push({id:sample.id,candidates,highlights,ui_seconds:Number(((performance.now()-started)/1000).toFixed(3)),preview_chars:preview.length});
  }
  const summary = {passed:true,generated_at:new Date().toISOString(),samples:metrics};
  await writeFile(join(reportRoot,'frontend-summary.json'),JSON.stringify(summary,null,2)+'\n');
  console.log(JSON.stringify(summary,null,2));
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
