import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {extname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright-core';
import {FIXTURES, SAMPLE_NAMES} from './frontend.fixtures.js';

const root = fileURLToPath(new URL('../dist/', import.meta.url));
const mime = {'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json'};

function staticServer() {
  return createServer(async (request, response) => {
    try {
      const pathname = new URL(request.url, 'http://localhost').pathname;
      const path = join(root, pathname === '/' ? 'index.html' : pathname);
      response.writeHead(200, {'Content-Type': mime[extname(path)] || 'application/octet-stream'});
      response.end(await readFile(path));
    } catch {
      response.writeHead(404).end('not found');
    }
  });
}

async function upload(page, name) {
  const previousId = await page.locator('#requestId').textContent();
  await page.locator('#file').setInputFiles({name, mimeType:'text/plain', buffer:Buffer.from(name)});
  await page.waitForFunction(oldId => document.querySelector('#requestId')?.textContent !== oldId, previousId);
  await page.locator('#fileName').filter({hasText:name}).waitFor();
  await page.locator('#progressLabel').filter({hasText:'识别完成'}).waitFor({timeout:15000});
}

async function finishReview(page) {
  const confirmRequired = page.locator('#confirmRequired');
  if (await confirmRequired.isEnabled()) await confirmRequired.click();
  while (await page.locator('.entity.pending').count()) {
    await page.locator('.entity.pending').first().locator('[data-review="reject"]').click();
  }
  await page.locator('#previewApproved').check();
}

const server = staticServer();
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const port = server.address().port;
const browser = await chromium.launch({headless:true, executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'});
const page = await browser.newPage({viewport:{width:1440,height:900}, acceptDownloads:true});
const jobs = new Map();

await page.addInitScript(() => {
  window.__phaseHistory = [];
  addEventListener('DOMContentLoaded', () => new MutationObserver(() => {
    const value = document.querySelector('#progressLabel')?.textContent;
    if (value && window.__phaseHistory.at(-1) !== value) window.__phaseHistory.push(value);
  }).observe(document.documentElement, {subtree:true, childList:true, characterData:true}));
});

await page.route('http://127.0.0.1:8766/**', async route => {
  const url = new URL(route.request().url());
  if (url.pathname === '/health') return route.fulfill({status:200, json:{status:'ok'}});
  if (url.pathname === '/analyze-upload') {
    const body = JSON.parse(route.request().postData());
    const id = route.request().headers()['x-request-id'];
    jobs.set(id, {name:body.name, step:0});
    return route.fulfill({status:202, json:{job_id:id,status:'queued'}});
  }
  const id = decodeURIComponent(url.pathname.split('/').at(-1));
  const job = jobs.get(id);
  if (!job) return route.fulfill({status:404, json:{status:'missing'}});
  if (job.name === 'failure.txt') {
    if (job.step++ === 0) return route.fulfill({json:{status:'queued',phase:'queued',message:'已进入本地队列'}});
    return route.fulfill({json:{status:'error',phase:'error',message:'固定样例模拟提取失败'}});
  }
  const states = [
    {status:'queued',phase:'queued',message:'已进入本地队列',progress:5},
    {status:'running',phase:'extract',message:'正在提取文本',progress:25,name:job.name},
    {status:'running',phase:'ner',message:'模型识别中：第 1 / 2 段',progress:62},
    {status:'running',phase:'ner',message:'模型识别中：第 2 / 2 段',progress:95},
    {status:'done',phase:'done',progress:100,result:FIXTURES[job.name]}
  ];
  return route.fulfill({json:states[Math.min(job.step++, states.length - 1)]});
});

try {
  await page.goto(`http://127.0.0.1:${port}`);
  await page.locator('#status').filter({hasText:'本地服务已连接'}).waitFor();

  for (const name of SAMPLE_NAMES) {
    await upload(page, name);
    const fixture = FIXTURES[name];
    assert.equal(await page.locator('.entity').count(), fixture.entities.length, `${name}: candidate count`);
    assert.equal(await page.locator('.entity-mark').count() <= fixture.entities.length, true, `${name}: highlights account for overlaps`);
    assert.equal(await page.locator('#exportText').isDisabled(), true, `${name}: export blocked before review`);
    await finishReview(page);
    await page.locator('.tab[data-view="preview"]').click();
    assert.equal(await page.locator('#exportText').isEnabled(), true, `${name}: export enabled after preview approval`);
    if (name === 'repeated.txt') {
      const preview = await page.locator('#preview').textContent();
      assert.equal((preview.match(/人员A/g) || []).length, 2, 'repeated name reuses pseudonym');
    }
    if (name === 'roles.txt') {
      assert.equal(await page.locator('.entity.overlap').count() > 0, true, 'overlap is visible');
      await page.locator('#reviewPanel').evaluate(element => { element.scrollTop = 0; });
      await page.screenshot({path:join(root, 'frontend-regression.png'), fullPage:true});
    }
  }

  await upload(page, 'short.txt');
  const history = await page.evaluate(() => window.__phaseHistory);
  for (const expected of ['已进入本地队列','正在提取文本','第 1 / 2 段','第 2 / 2 段','识别完成']) {
    assert.equal(history.some(item => item.includes(expected)), true, `phase rendered: ${expected}`);
  }

  await page.locator('#file').setInputFiles({name:'failure.txt',mimeType:'text/plain',buffer:Buffer.from('fail')});
  await page.locator('#progressLabel').filter({hasText:'处理失败：后端处理失败：固定样例模拟提取失败'}).waitFor({timeout:10000});
  assert.equal(await page.locator('.entity').count(), 0, 'failed job clears previous candidates');
  assert.equal(await page.locator('#status').textContent(), '本地服务已连接', 'job failure does not mark service offline');
  console.log(`Frontend regression passed: ${SAMPLE_NAMES.join(', ')} + failure state`);
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
